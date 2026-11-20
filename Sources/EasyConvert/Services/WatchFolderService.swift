import Foundation
import AppKit
import UserNotifications

struct WatchFolderRule: Identifiable, Codable, Sendable, Equatable {
    var id: UUID = UUID()
    var folderPath: String
    var preset: String
    var isEnabled: Bool = true

    var folderURL: URL {
        URL(fileURLWithPath: folderPath)
    }
}

final class WatchFolderService: @unchecked Sendable {
    static let shared = WatchFolderService()

    private var activeSources: [UUID: DispatchSourceFileSystemObject] = [:]
    private var fileDescriptors: [UUID: Int32] = [:]
    private var debounceWorkItems: [UUID: DispatchWorkItem] = [:]
    private var inFlightPaths: Set<String> = []
    private var processedKeys: Set<String> = []
    private let lock = NSLock()
    private let queue = DispatchQueue(label: "com.thatonemacosdev.tossy.watchfolder", qos: .utility)

    private let imageConverter = ImageConverter()
    private let videoConverter = VideoConverter()
    private let audioConverter = AudioConverter()

    private let storageKey = "tossy_watch_folders"

    init() {}

    /// Starts monitoring all enabled saved rules from UserDefaults.
    func start() {
        let rules = savedRules()
        stopAll()
        for rule in rules where rule.isEnabled {
            startMonitoring(rule: rule)
        }
    }

    /// Loads saved rules from UserDefaults.
    func savedRules() -> [WatchFolderRule] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([WatchFolderRule].self, from: data) else {
            return []
        }
        return decoded
    }

    /// Saves rules and updates active dispatch sources.
    func syncRules(_ rules: [WatchFolderRule]) {
        if let data = try? JSONEncoder().encode(rules) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
        stopAll()
        for rule in rules where rule.isEnabled {
            startMonitoring(rule: rule)
        }
    }

    /// Starts monitoring a single directory using DispatchSourceFileSystemObject.
    func startMonitoring(rule: WatchFolderRule) {
        stopMonitoring(ruleId: rule.id)

        guard rule.isEnabled, FileManager.default.fileExists(atPath: rule.folderPath) else {
            return
        }

        let fd = open(rule.folderPath, O_EVTONLY)
        guard fd >= 0 else { return }

        lock.lock()
        fileDescriptors[rule.id] = fd
        lock.unlock()

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .extend, .attrib, .link],
            queue: queue
        )

        source.setEventHandler { [weak self] in
            self?.scheduleDebouncedScan(rule: rule)
        }

        source.setCancelHandler {
            close(fd)
        }

        lock.lock()
        activeSources[rule.id] = source
        lock.unlock()

        source.resume()

        // Immediate initial scan to pick up any unconverted files in the folder
        queue.async { [weak self] in
            self?.scanFolder(rule: rule)
        }
    }

    /// Stops monitoring a specific rule.
    func stopMonitoring(ruleId: UUID) {
        lock.lock()
        defer { lock.unlock() }

        if let item = debounceWorkItems.removeValue(forKey: ruleId) {
            item.cancel()
        }
        if let source = activeSources.removeValue(forKey: ruleId) {
            source.cancel()
        }
        if let fd = fileDescriptors.removeValue(forKey: ruleId) {
            close(fd)
        }
    }

    /// Stops monitoring all active folders.
    func stopAll() {
        lock.lock()
        let keys = Array(activeSources.keys)
        lock.unlock()

        for key in keys {
            stopMonitoring(ruleId: key)
        }
    }

    private func scheduleDebouncedScan(rule: WatchFolderRule) {
        lock.lock()
        debounceWorkItems[rule.id]?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            self?.scanFolder(rule: rule)
        }
        debounceWorkItems[rule.id] = workItem
        lock.unlock()

        queue.asyncAfter(deadline: .now() + 0.15, execute: workItem)
    }

    private func scanFolder(rule: WatchFolderRule) {
        guard let items = try? FileManager.default.contentsOfDirectory(
            at: rule.folderURL,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        let settings = AppSettings.shared

        for item in items {
            let path = item.path
            let destinationFolder = settings.destinationFolder(for: item) ?? rule.folderURL

            lock.lock()
            if inFlightPaths.contains(path) {
                lock.unlock()
                continue
            }

            let key = makeKey(for: item, ruleId: rule.id)
            if processedKeys.contains(key) {
                lock.unlock()
                continue
            }

            if isAlreadyConverted(sourceURL: item, rule: rule, destinationFolder: destinationFolder) {
                processedKeys.insert(key)
                lock.unlock()
                continue
            }

            inFlightPaths.insert(path)
            lock.unlock()

            Task {
                await self.processFile(item, rule: rule, destinationFolder: destinationFolder, key: key)
            }
        }
    }

    private func markProcessed(_ key: String) {
        lock.lock()
        defer { lock.unlock() }
        processedKeys.insert(key)
    }

    private func removeFromInFlight(_ path: String) {
        lock.lock()
        defer { lock.unlock() }
        inFlightPaths.remove(path)
    }

    private func isAlreadyConverted(sourceURL: URL, rule: WatchFolderRule, destinationFolder: URL) -> Bool {
        let ext = sourceURL.pathExtension.lowercased()
        let fileName = sourceURL.lastPathComponent
        let baseName = sourceURL.deletingPathExtension().lastPathComponent

        // Ignore temporary or internal files
        if fileName.hasPrefix(".") || ["tmp", "crdownload", "part", "download", "swp"].contains(ext) {
            return true
        }

        var targetURL: URL?

        switch rule.preset {
        case "Auto-convert Images to WebP", "webp":
            if ext == "webp" { return true }
            guard ImageFormat.readableExtensions.contains(ext) else { return true }
            targetURL = destinationFolder.appendingPathComponent("\(baseName).webp")

        case "Auto-convert Images to PNG", "png":
            if ext == "png" { return true }
            guard ImageFormat.readableExtensions.contains(ext) else { return true }
            targetURL = destinationFolder.appendingPathComponent("\(baseName).png")

        case "Auto-convert Videos to MP4", "mp4":
            if ext == "mp4" { return true }
            guard VideoFormat.readableExtensions.contains(ext) else { return true }
            targetURL = destinationFolder.appendingPathComponent("\(baseName).mp4")

        case "Auto-compress PDFs (150 DPI)", "compress_pdf":
            if fileName.contains("-compressed") || ext != "pdf" { return true }
            targetURL = destinationFolder.appendingPathComponent("\(baseName)-compressed.pdf")

        case "Auto-strip EXIF Metadata", "strip_exif":
            if fileName.contains("-sanitized") { return true }
            guard ImageFormat.readableExtensions.contains(ext) else { return true }
            targetURL = destinationFolder.appendingPathComponent("\(baseName)-sanitized.\(ext)")

        case "Auto-extract MP3 Audio", "extract_mp3", "mp3":
            if ext == "mp3" { return true }
            guard VideoFormat.readableExtensions.contains(ext) || AudioFormat.readableExtensions.contains(ext) else { return true }
            targetURL = destinationFolder.appendingPathComponent("\(baseName).mp3")

        default:
            targetURL = destinationFolder.appendingPathComponent("\(baseName).\(rule.preset)")
        }

        if let targetURL, FileManager.default.fileExists(atPath: targetURL.path) {
            if let targetSize = (try? FileManager.default.attributesOfItem(atPath: targetURL.path))?[.size] as? Int64, targetSize > 0 {
                return true
            }
        }

        return false
    }

    private func processFile(_ sourceURL: URL, rule: WatchFolderRule, destinationFolder: URL, key: String) async {
        defer {
            removeFromInFlight(sourceURL.path)
        }

        let ext = sourceURL.pathExtension.lowercased()
        let fileName = sourceURL.lastPathComponent

        // Ignore hidden, temp, or in-flight downloads
        if fileName.hasPrefix(".") || ["tmp", "crdownload", "part", "download", "swp"].contains(ext) {
            return
        }

        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: sourceURL.path, isDirectory: &isDir), !isDir.boolValue else {
            return
        }

        // Wait until file is fully written and stable
        guard await waitForFileStability(at: sourceURL) else { return }

        let settings = AppSettings.shared
        var outputURL: URL?

        do {
            switch rule.preset {
            case "Auto-convert Images to WebP", "webp":
                guard ImageFormat.readableExtensions.contains(ext) && ext != "webp" else { return }
                let res = try await imageConverter.convert(
                    sourceURL: sourceURL,
                    to: .webp,
                    destinationFolder: destinationFolder,
                    preserveMetadata: true
                )
                outputURL = res.outputURLs.first

            case "Auto-convert Images to PNG", "png":
                guard ImageFormat.readableExtensions.contains(ext) && ext != "png" else { return }
                let res = try await imageConverter.convert(
                    sourceURL: sourceURL,
                    to: .png,
                    destinationFolder: destinationFolder,
                    preserveMetadata: true
                )
                outputURL = res.outputURLs.first

            case "Auto-convert Videos to MP4", "mp4":
                guard VideoFormat.readableExtensions.contains(ext) && ext != "mp4" else { return }
                let res = try await videoConverter.convert(
                    sourceURL: sourceURL,
                    to: .mp4H264,
                    destinationFolder: destinationFolder,
                    preserveMetadata: true,
                    onProgress: { _ in }
                )
                outputURL = res.outputURL

            case "Auto-compress PDFs (150 DPI)", "compress_pdf":
                guard ext == "pdf" && !fileName.contains("-compressed") else { return }
                let safeDest = OutputNaming.uniqueOutputURL(for: sourceURL, fileExtension: "pdf", destinationFolder: destinationFolder)
                let res = try await PDFCompressService.shared.compress(
                    source: sourceURL,
                    preset: .medium,
                    destination: safeDest
                )
                outputURL = res.outputURL

            case "Auto-strip EXIF Metadata", "strip_exif":
                guard ImageFormat.readableExtensions.contains(ext) && !fileName.contains("-sanitized") else { return }
                let safeDest = OutputNaming.uniqueDestinationURL(desiredURL: destinationFolder.appendingPathComponent("\(sourceURL.deletingPathExtension().lastPathComponent)-sanitized.\(ext)"))
                outputURL = try await EXIFSanitizerService.shared.stripMetadata(
                    sourceURL: sourceURL,
                    destinationURL: safeDest
                )

            case "Auto-extract MP3 Audio", "extract_mp3", "mp3":
                guard ext != "mp3" && (VideoFormat.readableExtensions.contains(ext) || AudioFormat.readableExtensions.contains(ext)) else { return }
                let safeDest = OutputNaming.uniqueOutputURL(for: sourceURL, fileExtension: "mp3", destinationFolder: destinationFolder)
                outputURL = try await AudioExtractorService.shared.extractAudioTrack(
                    videoURL: sourceURL,
                    format: .mp3,
                    destinationURL: safeDest
                )

            default:
                await HeadlessConversionWorker.shared.processFiles([sourceURL], targetFormat: rule.preset, isSilent: true)
                return
            }

            guard let out = outputURL else { return }

            // Mark source and output in processed cache so watcher ignores them
            markProcessed(key)
            let outKey = makeKey(for: out, ruleId: rule.id)
            markProcessed(outKey)

            if settings.deleteSourceAfterConversion {
                try? FileManager.default.removeItem(at: sourceURL)
            }

            await MainActor.run {
                settings.recordSuccessfulConversion(count: 1)
                if settings.playCompletionSound {
                    NSSound(named: "Glass")?.play()
                }
            }

            if settings.notifyOnComplete {
                postNotification(source: sourceURL, output: out)
            }

            if settings.autoRevealInFinder {
                await MainActor.run {
                    NSWorkspace.shared.activateFileViewerSelecting([out])
                }
            }
        } catch {
            print("WatchFolder conversion failed for \(sourceURL.lastPathComponent): \(error.localizedDescription)")
        }
    }

    private func waitForFileStability(at url: URL) async -> Bool {
        // If file already exists and was modified over 2 seconds ago, verify read handle and return immediately
        if let attr = try? FileManager.default.attributesOfItem(atPath: url.path),
           let currentSize = attr[.size] as? Int64, currentSize > 0,
           let mdate = attr[.modificationDate] as? Date,
           Date().timeIntervalSince(mdate) > 2.0 {
            if let handle = try? FileHandle(forReadingFrom: url) {
                try? handle.close()
                return true
            }
        }

        var previousSize: Int64 = -1
        for _ in 0..<20 {
            guard let attr = try? FileManager.default.attributesOfItem(atPath: url.path),
                  let currentSize = attr[.size] as? Int64, currentSize > 0 else {
                try? await Task.sleep(nanoseconds: 100_000_000)
                continue
            }
            if currentSize == previousSize {
                if let handle = try? FileHandle(forReadingFrom: url) {
                    try? handle.close()
                    return true
                }
            }
            previousSize = currentSize
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
        return false
    }

    private func makeKey(for url: URL, ruleId: UUID) -> String {
        let attr = try? FileManager.default.attributesOfItem(atPath: url.path)
        let size = (attr?[.size] as? Int64) ?? 0
        let mtime = (attr?[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
        return "\(url.path)_\(size)_\(mtime)_\(ruleId.uuidString)"
    }

    private func postNotification(source: URL, output: URL) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }

            let content = UNMutableNotificationContent()
            content.title = "Watch Folder: Converted"
            content.body = "\(source.lastPathComponent) → \(output.lastPathComponent)"
            content.sound = UNNotificationSound.default

            let request = UNNotificationRequest(
                identifier: "com.easyconvert.watchfolder.\(UUID().uuidString)",
                content: content,
                trigger: nil
            )
            center.add(request)
        }
    }
}
