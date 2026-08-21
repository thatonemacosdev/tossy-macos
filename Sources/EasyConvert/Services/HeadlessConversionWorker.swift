import Foundation
import AppKit
import UserNotifications

final class HeadlessConversionWorker: @unchecked Sendable {
    static let shared = HeadlessConversionWorker()
    
    private let imageConverter = ImageConverter()
    private let videoConverter = VideoConverter()
    private let audioConverter = AudioConverter()
    
    private init() {}
    
    func processFiles(_ fileURLs: [URL], targetFormat: String?, isSilent: Bool = true) async {
        guard !fileURLs.isEmpty else { return }
        
        let settings = AppSettings.shared
        var completedCount = 0
        var failedCount = 0
        var firstOutputURL: URL?
        var totalOriginalBytes: Int64 = 0
        var totalConvertedBytes: Int64 = 0
        
        // Calculate initial sizes
        for url in fileURLs {
            if let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) {
                totalOriginalBytes += size
            }
        }
        
        let concurrency = settings.maxConcurrentJobs
        
        await withTaskGroup(of: URL?.self) { group in
            var iterator = fileURLs.makeIterator()
            var activeCount = 0
            
            while activeCount < concurrency, let nextURL = iterator.next() {
                activeCount += 1
                group.addTask {
                    await self.convertSingleFile(nextURL, targetFormat: targetFormat)
                }
            }
            
            while let result = await group.next() {
                if let output = result {
                    completedCount += 1
                    if firstOutputURL == nil { firstOutputURL = output }
                    if let size = (try? FileManager.default.attributesOfItem(atPath: output.path)[.size] as? Int64) {
                        totalConvertedBytes += size
                    }
                } else {
                    failedCount += 1
                }
                
                if let nextURL = iterator.next() {
                    group.addTask {
                        await self.convertSingleFile(nextURL, targetFormat: targetFormat)
                    }
                }
            }
        }
        
        // Completion notifications & sound
        if settings.playCompletionSound {
            NSSound(named: "Glass")?.play()
        }
        
        if settings.notifyOnComplete {
            postCompletionNotification(
                completedCount: completedCount,
                failedCount: failedCount,
                targetFormat: targetFormat?.uppercased() ?? "Target Format",
                firstOutputURL: firstOutputURL,
                originalBytes: totalOriginalBytes,
                convertedBytes: totalConvertedBytes
            )
        }
        
        if settings.autoRevealInFinder, let firstOutput = firstOutputURL {
            NSWorkspace.shared.activateFileViewerSelecting([firstOutput])
        }
    }
    
    private func convertSingleFile(_ sourceURL: URL, targetFormat: String?) async -> URL? {
        let settings = AppSettings.shared
        let destinationFolder = settings.destinationFolder(for: sourceURL)
        let ext = (targetFormat ?? "").lowercased()
        
        do {
            // Check if Image Format
            if let imageFmt = ImageFormat.allCases.first(where: { $0.fileExtension.lowercased() == ext }) {
                let result = try await imageConverter.convert(
                    sourceURL: sourceURL,
                    to: imageFmt,
                    destinationFolder: destinationFolder,
                    preserveMetadata: true
                )
                if let output = result.outputURLs.first {
                    handlePostConversion(sourceURL: sourceURL)
                    return output
                }
            }
            
            // Check if Video Format
            if let videoFmt = VideoFormat.allCases.first(where: { $0.fileExtension.lowercased() == ext }) {
                let result = try await videoConverter.convert(
                    sourceURL: sourceURL,
                    to: videoFmt,
                    destinationFolder: destinationFolder,
                    preserveMetadata: true,
                    onProgress: { _ in }
                )
                handlePostConversion(sourceURL: sourceURL)
                return result.outputURL
            }
            
            // Check if Audio Format
            if let audioFmt = AudioFormat.allCases.first(where: { $0.fileExtension.lowercased() == ext }) {
                let result = try await audioConverter.convert(
                    sourceURL: sourceURL,
                    to: audioFmt,
                    destinationFolder: destinationFolder,
                    preserveMetadata: true,
                    onProgress: { _ in }
                )
                handlePostConversion(sourceURL: sourceURL)
                return result.outputURL
            }
            
            // Default fallback: detect category
            let sourceExt = sourceURL.pathExtension.lowercased()
            if ImageFormat.readableExtensions.contains(sourceExt) {
                let result = try await imageConverter.convert(
                    sourceURL: sourceURL,
                    to: .png,
                    destinationFolder: destinationFolder,
                    preserveMetadata: true
                )
                if let output = result.outputURLs.first {
                    handlePostConversion(sourceURL: sourceURL)
                    return output
                }
            }
            
            if VideoFormat.readableExtensions.contains(sourceExt) {
                let result = try await videoConverter.convert(
                    sourceURL: sourceURL,
                    to: .mp4H264,
                    destinationFolder: destinationFolder,
                    preserveMetadata: true,
                    onProgress: { _ in }
                )
                handlePostConversion(sourceURL: sourceURL)
                return result.outputURL
            }
            
            if AudioFormat.readableExtensions.contains(sourceExt) {
                let result = try await audioConverter.convert(
                    sourceURL: sourceURL,
                    to: .mp3,
                    destinationFolder: destinationFolder,
                    preserveMetadata: true,
                    onProgress: { _ in }
                )
                handlePostConversion(sourceURL: sourceURL)
                return result.outputURL
            }
        } catch {
            return nil
        }
        
        return nil
    }
    
    private func handlePostConversion(sourceURL: URL) {
        if AppSettings.shared.deleteSourceAfterConversion {
            try? FileManager.default.removeItem(at: sourceURL)
        }
    }
    
    private func postCompletionNotification(
        completedCount: Int,
        failedCount: Int,
        targetFormat: String,
        firstOutputURL: URL?,
        originalBytes: Int64,
        convertedBytes: Int64
    ) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            
            let content = UNMutableNotificationContent()
            content.title = "Tossy Conversion Complete"
            
            var summary = "Converted \(completedCount) \(completedCount == 1 ? "file" : "files") to \(targetFormat)"
            if originalBytes > 0 && convertedBytes > 0 {
                let diff = originalBytes - convertedBytes
                if diff > 0 {
                    let savedMB = Double(diff) / 1_000_000.0
                    summary += String(format: " (Saved %.1f MB)", savedMB)
                }
            }
            if failedCount > 0 {
                summary += " (\(failedCount) failed)"
            }
            content.body = summary
            content.sound = UNNotificationSound.default
            
            let request = UNNotificationRequest(
                identifier: "com.easyconvert.notification.\(UUID().uuidString)",
                content: content,
                trigger: nil
            )
            center.add(request)
        }
    }
}
