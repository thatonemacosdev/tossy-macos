import Foundation

enum AnimatedWebPError: LocalizedError {
    case ffmpegUnavailable
    case img2webpUnavailable
    case frameExtractionFailed
    case assemblyFailed(String)

    var errorDescription: String? {
        switch self {
        case .ffmpegUnavailable: return "ffmpeg isn't available for frame extraction."
        case .img2webpUnavailable: return "The bundled img2webp tool was not found."
        case .frameExtractionFailed: return "Failed to extract frames from the input video."
        case .assemblyFailed(let msg): return msg
        }
    }
}

final class AnimatedWebPConverter {
    private let ffmpeg = FFmpegService()

    func convert(
        sourceURL: URL,
        destinationFolder: URL?,
        targetWidth: Int? = nil,
        customBaseName: String? = nil,
        onProgress: @escaping (Double) -> Void
    ) async throws -> VideoConversionResult {
        guard FFmpegLocator.isAvailable else {
            throw AnimatedWebPError.ffmpegUnavailable
        }
        guard let img2webpPath = WebPLocator.img2webpPath else {
            throw AnimatedWebPError.img2webpUnavailable
        }

        let outputURL = OutputNaming.uniqueOutputURL(
            for: sourceURL,
            fileExtension: "webp",
            destinationFolder: destinationFolder,
            baseNameOverride: customBaseName
        )

        let duration = MediaProbe.probe(url: sourceURL)?.durationSeconds

        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let framePattern = tempDir.appendingPathComponent("frame_%06d.png").path

        var vfFilter = "fps=15"
        if let targetWidth, targetWidth > 0 {
            vfFilter += ",scale=\(targetWidth):-2"
        } else {
            vfFilter += ",scale=480:-2"
        }

        let ffmpegArgs = ["-y", "-i", sourceURL.path, "-vf", vfFilter, "-progress", "pipe:1", "-nostats", framePattern]

        onProgress(0.1)
        do {
            try await ffmpeg.run(arguments: ffmpegArgs, totalDuration: duration) { prog in
                onProgress(0.1 + prog * 0.6)
            }
        } catch {
            throw AnimatedWebPError.frameExtractionFailed
        }

        let frameFiles = (try? FileManager.default.contentsOfDirectory(atPath: tempDir.path))?
            .filter { $0.hasPrefix("frame_") && $0.hasSuffix(".png") }
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending } ?? []

        guard !frameFiles.isEmpty else {
            throw AnimatedWebPError.frameExtractionFailed
        }

        var img2webpArgs = ["-min_size", "-d", "67"]
        for frame in frameFiles {
            img2webpArgs.append(tempDir.appendingPathComponent(frame).path)
        }
        img2webpArgs += ["-o", outputURL.path]

        let process = Process()
        process.executableURL = URL(fileURLWithPath: img2webpPath)
        process.arguments = img2webpArgs

        let errorPipe = Pipe()
        process.standardError = errorPipe
        process.standardOutput = FileHandle.nullDevice

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            process.terminationHandler = { proc in
                if proc.terminationStatus == 0 {
                    continuation.resume()
                } else {
                    let data = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    let message = String(data: data, encoding: .utf8) ?? "img2webp failed."
                    continuation.resume(throwing: AnimatedWebPError.assemblyFailed(message))
                }
            }
            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }

        onProgress(1.0)
        return VideoConversionResult(outputURL: outputURL, note: nil)
    }
}
