import Foundation

final class VideoGeometrySpeedService: Sendable {
    static let shared = VideoGeometrySpeedService()
    
    init() {}
    
    /// Rotates or flips a video stream.
    /// degrees: 90 (clockwise), 180, 270 (counter-clockwise).
    func rotateVideo(
        sourceURL: URL,
        degrees: Int = 0,
        flipHorizontal: Bool = false,
        flipVertical: Bool = false,
        destinationURL: URL
    ) async throws -> URL {
        return try await transformVideo(
            sourceURL: sourceURL,
            degrees: degrees,
            flipHorizontal: flipHorizontal,
            flipVertical: flipVertical,
            speedMultiplier: 1.0,
            destinationURL: destinationURL
        )
    }
    
    /// Adjusts video playback speed (0.25x to 4.0x) with optional audio pitch preservation.
    func changeSpeed(
        sourceURL: URL,
        speedMultiplier: Double,
        preserveAudioPitch: Bool = true,
        destinationURL: URL
    ) async throws -> URL {
        return try await transformVideo(
            sourceURL: sourceURL,
            degrees: 0,
            flipHorizontal: false,
            flipVertical: false,
            speedMultiplier: speedMultiplier,
            destinationURL: destinationURL
        )
    }
    
    /// Combined video transformation engine (rotation, horizontal/vertical flip, and variable speed).
    func transformVideo(
        sourceURL: URL,
        degrees: Int = 0,
        flipHorizontal: Bool = false,
        flipVertical: Bool = false,
        speedMultiplier: Double = 1.0,
        destinationURL: URL
    ) async throws -> URL {
        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            throw MediaStudioError.fileNotFound(sourceURL)
        }
        guard speedMultiplier >= 0.25 && speedMultiplier <= 4.0 else {
            throw MediaStudioError.unsupportedOperation("Speed multiplier must be between 0.25x and 4.0x (requested: \(speedMultiplier)x)")
        }
        guard let ffmpegPath = FFmpegLocator.ffmpegPath else {
            throw MediaStudioError.executionFailed("ffmpeg binary not found")
        }
        
        let destFolder = destinationURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: destFolder, withIntermediateDirectories: true)
        let safeDestination = OutputNaming.uniqueDestinationURL(desiredURL: destinationURL)
        
        let probe = MediaProbe.probe(url: sourceURL)
        let hasAudio = probe?.hasAudio ?? true
        
        var videoFilters: [String] = []
        
        if degrees == 90 {
            videoFilters.append("transpose=1")
        } else if degrees == 180 {
            videoFilters.append("transpose=2,transpose=2")
        } else if degrees == 270 {
            videoFilters.append("transpose=2")
        }
        
        if flipHorizontal {
            videoFilters.append("hflip")
        }
        if flipVertical {
            videoFilters.append("vflip")
        }
        
        let isSpeedChanged = abs(speedMultiplier - 1.0) > 0.001
        if isSpeedChanged {
            let ptsFactor = 1.0 / speedMultiplier
            videoFilters.append(String(format: "setpts=%.4f*PTS", ptsFactor))
        }
        
        var arguments = ["-y", "-i", sourceURL.path]
        
        if isSpeedChanged && hasAudio {
            var audioFilters: [String] = []
            var remainingSpeed = speedMultiplier
            
            while remainingSpeed > 2.0 {
                audioFilters.append("atempo=2.0")
                remainingSpeed /= 2.0
            }
            while remainingSpeed < 0.5 {
                audioFilters.append("atempo=0.5")
                remainingSpeed /= 0.5
            }
            audioFilters.append(String(format: "atempo=%.4f", remainingSpeed))
            
            let vfString = videoFilters.isEmpty ? "null" : videoFilters.joined(separator: ",")
            let afString = audioFilters.joined(separator: ",")
            
            arguments += [
                "-filter_complex", "[0:v]\(vfString)[v];[0:a]\(afString)[a]",
                "-map", "[v]",
                "-map", "[a]",
                "-c:v", "libx264",
                "-preset", "veryfast",
                "-crf", "22",
                "-c:a", "aac",
                safeDestination.path
            ]
        } else {
            if !videoFilters.isEmpty {
                arguments += ["-vf", videoFilters.joined(separator: ",")]
            }
            
            if isSpeedChanged {
                arguments += [
                    "-c:v", "libx264",
                    "-preset", "veryfast",
                    "-crf", "22"
                ]
            } else {
                arguments += ["-c:v", "libx264", "-preset", "veryfast"]
            }
            
            if hasAudio {
                arguments += ["-c:a", "copy"]
            } else {
                arguments += ["-an"]
            }
            
            arguments.append(safeDestination.path)
        }
        
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
            throw MediaStudioError.executionFailed("Video transformation failed (exit code \(process.terminationStatus)): \(errStr.suffix(300))")
        }
        
        return safeDestination
    }
}
