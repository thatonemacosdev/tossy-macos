import Foundation
import AVFoundation

enum VideoConversionError: LocalizedError {
    case unsupportedCombination
    case exportSessionCreationFailed
    case exportFailed(String)
    case formatUnavailable(String)
    case durationUnknown

    var errorDescription: String? {
        switch self {
        case .unsupportedCombination: return "This clip can't be exported in that format."
        case .exportSessionCreationFailed: return "Couldn't set up the export session."
        case .exportFailed(let message): return message
        case .formatUnavailable(let message): return message
        case .durationUnknown: return "Couldn't determine this clip's duration, so a target size can't be calculated."
        }
    }
}

struct VideoConversionResult {
    let outputURL: URL
    /// Set when a target size was requested — an estimated-vs-actual note (bitrate targeting
    /// is a single-pass estimate, not an exact guarantee).
    let note: String?
}

/// Transcodes video. The five common AVFoundation-native targets (MP4/MOV in H.264, HEVC, or
/// ProRes 422) go through `AVAssetExportSession`, routed through VideoToolbox's hardware codecs.
/// Everything else — MKV, WebM, AVI, and the rest of the container/codec zoo — goes through the
/// bundled ffmpeg, which AVFoundation simply can't read or write.
final class VideoConverter {
    private let ffmpeg = FFmpegService()

    /// Converts `sourceURL` to `format`, writing into `destinationFolder` (or alongside the
    /// source if `nil`). `onProgress` is called repeatedly with a 0...1 fraction. When
    /// `targetSizeBytes` is set (ffmpeg-backed formats only — AVFoundation's preset-based API
    /// doesn't expose bitrate control), the video (and audio, if present) bitrate is computed
    /// from the clip's duration to aim for that size; this is a single-pass estimate, not exact.
    func convert(
        sourceURL: URL,
        to format: VideoFormat,
        destinationFolder: URL?,
        targetSizeBytes: Int64? = nil,
        targetWidth: Int? = nil,
        onProgress: @escaping (Double) -> Void
    ) async throws -> VideoConversionResult {
        guard format.isAvailable else {
            throw VideoConversionError.formatUnavailable(format.unavailabilityReason ?? "This format isn't available.")
        }

        switch format.backend {
        case .avFoundation:
            guard targetSizeBytes == nil else {
                throw VideoConversionError.formatUnavailable("Target size isn't supported for hardware-accelerated formats like \(format.displayName). Pick an ffmpeg-backed format (e.g. MKV or WebM) to target a size.")
            }
            guard targetWidth == nil else {
                throw VideoConversionError.formatUnavailable("Custom resolution isn't supported for hardware-accelerated formats like \(format.displayName). Pick an ffmpeg-backed format (e.g. MKV or WebM) to resize.")
            }
            let outputURL = try await convertViaAVFoundation(sourceURL: sourceURL, format: format, destinationFolder: destinationFolder, onProgress: onProgress)
            return VideoConversionResult(outputURL: outputURL, note: nil)

        case .ffmpeg(let muxer, let videoCodec, let audioCodec, let extraArgs):
            return try await convertViaFFmpeg(
                sourceURL: sourceURL, outputExtension: format.fileExtension, muxer: muxer, videoCodec: videoCodec,
                audioCodec: audioCodec, extraArgs: extraArgs, destinationFolder: destinationFolder,
                targetSizeBytes: targetSizeBytes, targetWidth: targetWidth, onProgress: onProgress
            )
        }
    }

    /// "Keep original format" for video: re-encodes into the *same container* as the source
    /// (H.264 + AAC, broadly compatible) instead of picking one of the target formats above.
    /// Requires a target size — otherwise there's nothing to actually compress toward.
    func compressKeepingContainer(
        sourceURL: URL,
        destinationFolder: URL?,
        targetSizeBytes: Int64,
        targetWidth: Int? = nil,
        onProgress: @escaping (Double) -> Void
    ) async throws -> VideoConversionResult {
        let ext = sourceURL.pathExtension.isEmpty ? "mp4" : sourceURL.pathExtension.lowercased()
        return try await convertViaFFmpeg(
            sourceURL: sourceURL, outputExtension: ext, muxer: nil, videoCodec: "libx264",
            audioCodec: "aac", extraArgs: [], destinationFolder: destinationFolder,
            targetSizeBytes: targetSizeBytes, targetWidth: targetWidth, onProgress: onProgress
        )
    }

    private func convertViaAVFoundation(
        sourceURL: URL,
        format: VideoFormat,
        destinationFolder: URL?,
        onProgress: @escaping (Double) -> Void
    ) async throws -> URL {
        let asset = AVURLAsset(url: sourceURL)

        guard let preset = format.exportPreset,
              let exportSession = AVAssetExportSession(asset: asset, presetName: preset) else {
            throw VideoConversionError.exportSessionCreationFailed
        }
        guard let fileType = format.fileType, exportSession.supportedFileTypes.contains(fileType) else {
            throw VideoConversionError.unsupportedCombination
        }

        let outputURL = OutputNaming.uniqueOutputURL(
            for: sourceURL,
            fileExtension: format.fileExtension,
            destinationFolder: destinationFolder
        )
        exportSession.outputURL = outputURL
        exportSession.outputFileType = fileType

        let progressTask = Task {
            while !Task.isCancelled {
                onProgress(Double(exportSession.progress))
                try? await Task.sleep(nanoseconds: 150_000_000)
            }
        }

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            exportSession.exportAsynchronously {
                continuation.resume()
            }
        }
        progressTask.cancel()

        guard exportSession.status == .completed else {
            let message = exportSession.error?.localizedDescription ?? "The export did not complete."
            throw VideoConversionError.exportFailed(message)
        }

        onProgress(1.0)
        return outputURL
    }

    private func convertViaFFmpeg(
        sourceURL: URL,
        outputExtension: String,
        muxer: String?,
        videoCodec: String,
        audioCodec: String?,
        extraArgs: [String],
        destinationFolder: URL?,
        targetSizeBytes: Int64?,
        targetWidth: Int? = nil,
        onProgress: @escaping (Double) -> Void
    ) async throws -> VideoConversionResult {
        guard FFmpegLocator.isAvailable else {
            throw VideoConversionError.formatUnavailable("ffmpeg isn't available.")
        }

        let outputURL = OutputNaming.uniqueOutputURL(
            for: sourceURL,
            fileExtension: outputExtension,
            destinationFolder: destinationFolder
        )

        let duration = MediaProbe.probe(url: sourceURL)?.durationSeconds

        var arguments = ["-y", "-i", sourceURL.path, "-c:v", videoCodec]

        var note: String?
        if let targetSizeBytes {
            guard let duration, duration > 0 else { throw VideoConversionError.durationUnknown }
            let bitrates = Self.computeBitrates(targetSizeBytes: targetSizeBytes, durationSeconds: duration, hasAudio: audioCodec != nil)
            // Strip any codec-default bitrate args (e.g. DNxHD's fixed -b:v) — ours takes priority.
            arguments += Self.stripBitrateArgs(extraArgs)
            arguments += ["-b:v", "\(bitrates.videoBps)", "-maxrate", "\(Int(Double(bitrates.videoBps) * 1.45))", "-bufsize", "\(bitrates.videoBps * 2)"]
            if let audioCodec {
                arguments += ["-c:a", audioCodec, "-b:a", "\(bitrates.audioBps)"]
            } else {
                arguments += ["-an"]
            }
            note = "Targeted \(ByteSize.displayString(targetSizeBytes)) via estimated bitrate (single-pass, not exact)"
        } else {
            arguments += extraArgs
            if let audioCodec {
                arguments += ["-c:a", audioCodec]
            } else {
                arguments += ["-an"]
            }
        }

        if let targetWidth, targetWidth > 0 {
            // -2 keeps height even (required by most codecs) while preserving aspect ratio.
            arguments += ["-vf", "scale=\(targetWidth):-2"]
        }

        if let muxer {
            arguments += ["-f", muxer]
        }
        arguments += ["-progress", "pipe:1", "-nostats", outputURL.path]

        do {
            try await ffmpeg.run(arguments: arguments, totalDuration: duration, onProgress: onProgress)
        } catch {
            try? FileManager.default.removeItem(at: outputURL)
            throw error
        }

        if targetSizeBytes != nil {
            let size = (try? FileManager.default.attributesOfItem(atPath: outputURL.path)[.size] as? Int64) ?? 0
            note = "\(note ?? "") — actual: \(ByteSize.displayString(size))"
        }

        onProgress(1.0)
        return VideoConversionResult(outputURL: outputURL, note: note)
    }

    private static func computeBitrates(targetSizeBytes: Int64, durationSeconds: Double, hasAudio: Bool) -> (videoBps: Int, audioBps: Int) {
        let totalBits = Double(targetSizeBytes) * 8 * 0.95 // 5% margin for container/muxing overhead
        let totalBps = totalBits / durationSeconds
        guard hasAudio else { return (Int(max(totalBps, 50_000)), 0) }
        let audioBps = min(128_000, totalBps * 0.15)
        let videoBps = max(totalBps - audioBps, 50_000)
        return (Int(videoBps), Int(audioBps))
    }

    private static func stripBitrateArgs(_ args: [String]) -> [String] {
        var result: [String] = []
        var skipNext = false
        for arg in args {
            if skipNext { skipNext = false; continue }
            if arg == "-b:v" { skipNext = true; continue }
            result.append(arg)
        }
        return result
    }
}
