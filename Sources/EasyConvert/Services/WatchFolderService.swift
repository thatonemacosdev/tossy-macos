import Foundation

struct WatchFolderRule: Identifiable, Sendable {
    let id: UUID
    var folderURL: URL
    var targetFormat: String // e.g. "png", "mp3", "compress_pdf", "strip_exif"
    var isEnabled: Bool
    
    init(id: UUID = UUID(), folderURL: URL, targetFormat: String, isEnabled: Bool = true) {
        self.id = id
        self.folderURL = folderURL
        self.targetFormat = targetFormat
        self.isEnabled = isEnabled
    }
}

final class WatchFolderService: @unchecked Sendable {
    static let shared = WatchFolderService()
    
    private var activeSources: [UUID: DispatchSourceFileSystemObject] = [:]
    private var fileDescriptors: [UUID: Int32] = [:]
    private var processedFiles: Set<String> = []
    private let queue = DispatchQueue(label: "com.thatonemacosdev.tossy.watchfolder", qos: .utility)
    
    init() {}
    
    /// Starts monitoring a folder and executes the conversion handler whenever a new file is dropped.
    func startMonitoring(
        rule: WatchFolderRule,
        onNewFile: @escaping @Sendable (URL, WatchFolderRule) async -> Void
    ) {
        stopMonitoring(ruleId: rule.id)
        
        guard rule.isEnabled, FileManager.default.fileExists(atPath: rule.folderURL.path) else {
            return
        }
        
        let fd = open(rule.folderURL.path, O_EVTONLY)
        guard fd >= 0 else { return }
        fileDescriptors[rule.id] = fd
        
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .extend, .attrib, .link],
            queue: queue
        )
        
        source.setEventHandler { [weak self] in
            guard let self else { return }
            self.scanFolder(rule: rule, onNewFile: onNewFile)
        }
        
        source.setCancelHandler {
            close(fd)
        }
        
        activeSources[rule.id] = source
        source.resume()
        
        // Initial scan for existing files
        scanFolder(rule: rule, onNewFile: onNewFile)
    }
    
    /// Stops monitoring a specific rule.
    func stopMonitoring(ruleId: UUID) {
        if let source = activeSources[ruleId] {
            source.cancel()
            activeSources.removeValue(forKey: ruleId)
        }
        if let fd = fileDescriptors[ruleId] {
            close(fd)
            fileDescriptors.removeValue(forKey: ruleId)
        }
    }
    
    /// Stops monitoring all active folders.
    func stopAll() {
        for ruleId in Array(activeSources.keys) {
            stopMonitoring(ruleId: ruleId)
        }
    }
    
    private func scanFolder(
        rule: WatchFolderRule,
        onNewFile: @escaping @Sendable (URL, WatchFolderRule) async -> Void
    ) {
        guard let items = try? FileManager.default.contentsOfDirectory(
            at: rule.folderURL,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return }
        
        for item in items {
            let key = "\(item.path)_\(rule.id)"
            if processedFiles.contains(key) { continue }
            
            // Debounce: ensure file is not currently being written by checking size stability
            if let size = try? FileManager.default.attributesOfItem(atPath: item.path)[.size] as? Int64, size > 0 {
                processedFiles.insert(key)
                Task {
                    // Short wait for file write completion
                    try? await Task.sleep(nanoseconds: 100_000_000)
                    await onNewFile(item, rule)
                }
            }
        }
    }
}
