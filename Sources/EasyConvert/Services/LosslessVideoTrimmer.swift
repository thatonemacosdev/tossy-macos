import Foundation

enum MediaStudioError: LocalizedError, Sendable {
    case fileNotFound(URL)
    case invalidTimeRange(String)
    case executionFailed(String)
    case unsupportedOperation(String)
    case backgroundRemovalFailed(String)
    case noAudioTrackFound(URL)
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound(let url):
            return "File not found at: \(url.path)"
        case .invalidTimeRange(let details):
            return "Invalid time range: \(details)"
        case .executionFailed(let details):
            return "Processing failed: \(details)"
        case .unsupportedOperation(let details):
            return "Unsupported operation: \(details)"
        case .backgroundRemovalFailed(let details):
            return "Neural background removal failed: \(details)"
        case .noAudioTrackFound(let url):
            return "No audio tracks were found in '\(url.lastPathComponent)' to extract."
        }
    }
}

final class LosslessVideoTrimmer: Sendable {
    static let shared = LosslessVideoTrimmer()
    
    init() {}
    
    /// Trims a video file losslessly without re-encoding using stream copy (-c copy).
    func trim(
        sourceURL: URL,
        startTimeSeconds: Double,
        endTimeSeconds: Double,
        destinationURL: URL
    ) async throws -> URL {
        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            throw MediaStudioError.fileNotFound(sourceURL)
        }
        guard startTimeSeconds >= 0 && endTimeSeconds > startTimeSeconds else {
            throw MediaStudioError.invalidTimeRange("Start time (\(startTimeSeconds)s) must be before end time (\(endTimeSeconds)s)")
        }
        guard let ffmpegPath = FFmpegLocator.ffmpegPath else {
            throw MediaStudioError.executionFailed("ffmpeg binary not found")
        }
        
        let destFolder = destinationURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: destFolder, withIntermediateDirectories: true)
        let safeDestination = OutputNaming.uniqueDestinationURL(desiredURL: destinationURL)
        
        let startStr = String(format: "%.3f", startTimeSeconds)
        let durationStr = String(format: "%.3f", endTimeSeconds - startTimeSeconds)
        
        let arguments = [
            "-y",
            "-ss", startStr,
            "-i", sourceURL.path,
            "-t", durationStr,
            "-c", "copy",
            "-avoid_negative_ts", "make_zero",
            safeDestination.path
        ]
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: ffmpegPath)
        process.arguments = arguments
        let errPipe = Pipe()
        process.standardError = errPipe
        
        try process.run()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0, FileManager.default.fileExists(atPath: safeDestination.path) else {
            let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
            let errStr = String(data: errData, encoding: .utf8) ?? ""
            throw MediaStudioError.executionFailed("Video trim failed (exit code \(process.terminationStatus)): \(errStr.suffix(300))")
        }
        
        return safeDestination
    }
}
