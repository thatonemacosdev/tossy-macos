import Foundation

final class AudioExtractorService: Sendable {
    static let shared = AudioExtractorService()
    
    init() {}
    
    /// Extracts the audio track from a video file into a high-fidelity audio format (MP3, AAC, FLAC, WAV, etc.).
    /// Gracefully detects video files lacking audio tracks and aborts with a user-friendly error.
    func extractAudioTrack(
        videoURL: URL,
        format: AudioFormat = .mp3,
        bitrateKbps: Int? = 320,
        destinationURL: URL
    ) async throws -> URL {
        guard FileManager.default.fileExists(atPath: videoURL.path) else {
            throw MediaStudioError.fileNotFound(videoURL)
        }
        guard let ffmpegPath = FFmpegLocator.ffmpegPath else {
            throw MediaStudioError.executionFailed("ffmpeg binary not found")
        }
        
        // Probe media file to verify audio streams exist
        if let probe = MediaProbe.probe(url: videoURL), !probe.hasAudio {
            throw MediaStudioError.noAudioTrackFound(videoURL)
        }
        
        let destFolder = destinationURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: destFolder, withIntermediateDirectories: true)
        let safeDestination = OutputNaming.uniqueDestinationURL(desiredURL: destinationURL)
        
        var arguments = [
            "-y",
            "-i", videoURL.path,
            "-vn" // No video stream
        ]
        
        switch format {
        case .mp3:
            arguments += ["-c:a", "libmp3lame", "-b:a", "\(bitrateKbps ?? 320)k"]
        case .aac:
            arguments += ["-c:a", "aac", "-b:a", "\(bitrateKbps ?? 256)k"]
        case .flac:
            arguments += ["-c:a", "flac"]
        case .wav:
            arguments += ["-c:a", "pcm_s16le"]
        case .ogg:
            arguments += ["-c:a", "libopus", "-b:a", "\(bitrateKbps ?? 192)k"]
        case .alac:
            arguments += ["-c:a", "alac"]
        default:
            arguments += ["-c:a", "libmp3lame", "-b:a", "320k"]
        }
        
        arguments.append(safeDestination.path)
        
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
            throw MediaStudioError.executionFailed("Audio extraction failed (exit code \(process.terminationStatus)): \(errStr.suffix(300))")
        }
        
        return safeDestination
    }
    
    /// Strips the audio track completely from a video, generating a silent video with zero video re-encoding.
    func stripAudio(
        videoURL: URL,
        destinationURL: URL
    ) async throws -> URL {
        guard FileManager.default.fileExists(atPath: videoURL.path) else {
            throw MediaStudioError.fileNotFound(videoURL)
        }
        guard let ffmpegPath = FFmpegLocator.ffmpegPath else {
            throw MediaStudioError.executionFailed("ffmpeg binary not found")
        }
        
        let destFolder = destinationURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: destFolder, withIntermediateDirectories: true)
        let safeDestination = OutputNaming.uniqueDestinationURL(desiredURL: destinationURL)
        
        let arguments = [
            "-y",
            "-i", videoURL.path,
            "-an",
            "-c:v", "copy",
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
            throw MediaStudioError.executionFailed("Audio stripping failed (exit code \(process.terminationStatus)): \(errStr.suffix(300))")
        }
        
        return safeDestination
    }
}
