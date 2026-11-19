import Foundation
import AVFoundation

enum VideoConversionError: LocalizedError {
    case unsupportedCombination
    case exportSessionCreationFailed
    case exportFailed(String)
    case formatUnavailable(String)
    case durationUnknown
    case noAudioTrack

    var errorDescription: String? {
        switch self {
        case .unsupportedCombination: return "This clip can't be exported in that format."
        case .exportSessionCreationFailed: return "Couldn't set up the export session."
        case .exportFailed(let message): return message
        case .formatUnavailable(let message): return message
        case .durationUnknown: return "Couldn't determine this clip's duration, so a target size can't be calculated."
        case .noAudioTrack: return "This file doesn't have an audio track to extract."
        }
    }
}

struct VideoConversionResult {
    let outputURL: URL
    /// Set when a target size was requested  -  an estimated-vs-actual note (bitrate targeting
    /// is a single-pass estimate, not an exact guarantee).
    let note: String?
}

/// Transcodes video. The five common AVFoundation-native targets (MP4/MOV in H.264, HEVC, or
/// ProRes 422) go through `AVAssetExportSession`, routed through VideoToolbox's hardware codecs.
/// Everything else  -  MKV, WebM, AVI, and the rest of the container/codec zoo  -  goes through the
/// bundled ffmpeg, which AVFoundation simply can't read or write.
final class VideoConverter {
    private let ffmpeg = FFmpegService()

    /// Converts `sourceURL` to `format`, writing into `destinationFolder` (or alongside the
    /// source if `nil`). `onProgress` is called repeatedly with a 0...1 fraction. When
    /// `targetSizeBytes` is set (ffmpeg-backed formats only  -  AVFoundation's preset-based API
    /// doesn't expose bitrate control), the video (and audio, if present) bitrate is computed
    /// from the clip's duration to aim for that size; this is a single-pass estimate, not exact.
    func convert(
        sourceURL: URL,
        to format: VideoFormat,
        destinationFolder: URL?,
        targetSizeBytes: Int64? = nil,
        targetWidth: Int? = nil,
        customBaseName: String? = nil,
        preserveMetadata: Bool = true,
        onProgress: @escaping (Double) -> Void
    ) async throws -> VideoConversionResult {
        guard format.isAvailable else {
            throw VideoConversionError.formatUnavailable(format.unavailabilityReason ?? "This format isn't available.")
        }

        switch format.backend {
        case .avFoundation:
            let ext = sourceURL.pathExtension.lowercased()
            let appleNativeExtensions: Set<String> = ["mp4", "mov", "m4v"]
            let canAttemptAVFoundation = appleNativeExtensions.contains(ext) && targetSizeBytes == nil && targetWidth == nil
            
            if canAttemptAVFoundation {
                do {
                    let outputURL = try await convertViaAVFoundation(sourceURL: sourceURL, format: format, destinationFolder: destinationFolder, customBaseName: customBaseName, onProgress: onProgress)
                    return VideoConversionResult(outputURL: outputURL, note: nil)
                } catch {
                    // Fall back to FFmpeg if AVFoundation encounters an error
                }
            }

            // Route through ffmpeg to enable precise bitrate targeting, custom resolution scaling,
            // or to transcode non-Apple formats (WebM, MKV, AVI, etc.) and audio-only inputs
            let videoCfg = AppSettings.shared.videoConfig
            let preferHardware = videoCfg.encodingMode != "crf"
            let (vCodec, aCodec, extra): (String, String?, [String])
            switch format {
            case .mp4H264, .movH264:
                vCodec = preferHardware ? "h264_videotoolbox" : "libx264"
                aCodec = "aac"
                extra = []
            case .mp4Hevc, .movHevc:
                vCodec = preferHardware ? "hevc_videotoolbox" : "libx265"
                aCodec = "aac"
                extra = ["-tag:v", "hvc1"]
            case .movProRes422:
                vCodec = preferHardware ? "prores_videotoolbox" : "prores_ks"
                aCodec = "pcm_s16le"
                extra = ["-profile:v", "2"]
            case .movProRes4444:
                vCodec = preferHardware ? "prores_videotoolbox" : "prores_ks"
                aCodec = "pcm_s16le"
                extra = ["-profile:v", "4", "-pix_fmt", "yuva444p10le"]
            default:
                vCodec = preferHardware ? "h264_videotoolbox" : "libx264"
                aCodec = "aac"
                extra = []
            }
            return try await convertViaFFmpeg(
                sourceURL: sourceURL,
                outputExtension: format.fileExtension,
                muxer: nil,
                videoCodec: vCodec,
                audioCodec: aCodec,
                extraArgs: extra,
                destinationFolder: destinationFolder,
                targetSizeBytes: targetSizeBytes,
                targetWidth: targetWidth,
                customBaseName: customBaseName,
                preserveMetadata: preserveMetadata,
                onProgress: onProgress
            )

        case .ffmpeg(let muxer, let videoCodec, let audioCodec, let extraArgs):
            return try await convertViaFFmpeg(
                sourceURL: sourceURL, outputExtension: format.fileExtension, muxer: muxer, videoCodec: videoCodec,
                audioCodec: audioCodec, extraArgs: extraArgs, destinationFolder: destinationFolder,
                targetSizeBytes: targetSizeBytes, targetWidth: targetWidth, customBaseName: customBaseName,
                preserveMetadata: preserveMetadata, onProgress: onProgress
            )

        case .animatedWebp:
            return try await AnimatedWebPConverter().convert(
                sourceURL: sourceURL,
                destinationFolder: destinationFolder,
                targetWidth: targetWidth,
                customBaseName: customBaseName,
                onProgress: onProgress
            )
        }
    }

    /// "Keep original format" for video: re-encodes into the *same container* as the source
    /// (H.264 + AAC, broadly compatible) instead of picking one of the target formats above.
    /// Requires a target size  -  otherwise there's nothing to actually compress toward.
    func compressKeepingContainer(
        sourceURL: URL,
        destinationFolder: URL?,
        targetSizeBytes: Int64,
        targetWidth: Int? = nil,
        customBaseName: String? = nil,
        preserveMetadata: Bool = true,
        onProgress: @escaping (Double) -> Void
    ) async throws -> VideoConversionResult {
        let ext = sourceURL.pathExtension.isEmpty ? "mp4" : sourceURL.pathExtension.lowercased()
        let videoCfg = AppSettings.shared.videoConfig
        let preferHardware = videoCfg.encodingMode != "crf"
        let vCodec = preferHardware ? "h264_videotoolbox" : "libx264"
        return try await convertViaFFmpeg(
            sourceURL: sourceURL, outputExtension: ext, muxer: nil, videoCodec: vCodec,
            audioCodec: "aac", extraArgs: [], destinationFolder: destinationFolder,
            targetSizeBytes: targetSizeBytes, targetWidth: targetWidth, customBaseName: customBaseName,
            preserveMetadata: preserveMetadata, onProgress: onProgress
        )
    }

    private func convertViaAVFoundation(
        sourceURL: URL,
        format: VideoFormat,
        destinationFolder: URL?,
        customBaseName: String? = nil,
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
            destinationFolder: destinationFolder,
            baseNameOverride: customBaseName
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
            try? FileManager.default.removeItem(at: outputURL)
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
        customBaseName: String? = nil,
        preserveMetadata: Bool = true,
        onProgress: @escaping (Double) -> Void
    ) async throws -> VideoConversionResult {
        guard FFmpegLocator.isAvailable else {
            throw VideoConversionError.formatUnavailable("ffmpeg isn't available.")
        }

        let outputURL = OutputNaming.uniqueOutputURL(
            for: sourceURL,
            fileExtension: outputExtension,
            destinationFolder: destinationFolder,
            baseNameOverride: customBaseName
        )

        let probe = MediaProbe.probe(url: sourceURL)
        let hasVideo = probe?.hasVideo ?? true
        let duration = probe?.durationSeconds

        let videoCfg = AppSettings.shared.videoConfig

        // Zero-reencode stream copy when input streams already match target container
        if canStreamCopyRemux(sourceURL: sourceURL, targetExtension: outputExtension, probe: probe, videoCfg: videoCfg, targetSizeBytes: targetSizeBytes, targetWidth: targetWidth) {
            var remuxArgs = ["-y", "-i", sourceURL.path, "-c", "copy", "-movflags", "+faststart"]
            if !preserveMetadata {
                remuxArgs += ["-map_metadata", "-1"]
            }
            if probe?.videoCodec?.lowercased() == "hevc" && outputExtension.lowercased() == "mp4" {
                remuxArgs += ["-tag:v", "hvc1"]
            }
            remuxArgs += ["-progress", "pipe:1", "-nostats", outputURL.path]
            do {
                try await ffmpeg.run(arguments: remuxArgs, totalDuration: duration, onProgress: onProgress)
                onProgress(1.0)
                return VideoConversionResult(outputURL: outputURL, note: "Instant Remux (Zero Quality Loss)")
            } catch {
                // Fall back to transcoding if stream-copy remux fails
            }
        }

        var arguments = ["-y", "-hwaccel", "videotoolbox", "-i", sourceURL.path]

        if !preserveMetadata {
            arguments += ["-map_metadata", "-1"]
        }

        let isSoftwareEncoder = videoCodec.starts(with: "lib") || videoCodec == "prores_ks" || videoCodec == "mpeg2video" || videoCodec == "mpeg4"
        if isSoftwareEncoder && !extraArgs.contains("-threads") {
            let threadCount = max(1, ProcessInfo.processInfo.activeProcessorCount / 2)
            arguments += ["-threads", "\(threadCount)"]
        }

        if videoCodec == "libvpx-vp9" {
            if !extraArgs.contains("-cpu-used") {
                arguments += ["-cpu-used", "4"]
            }
            if !extraArgs.contains("-row-mt") {
                arguments += ["-row-mt", "1"]
            }
        }

        if hasVideo {
            arguments += ["-c:v", videoCodec]

            // Presets & Tuning for supported software encoders
            if videoCodec.contains("libx264") || videoCodec.contains("libx265") {
                arguments += ["-preset", videoCfg.x264Preset]
                if videoCfg.x264Tune != "none" {
                    arguments += ["-tune", videoCfg.x264Tune]
                }
            }
            
            // Pixel format (if not forced by format extraArgs)
            if !extraArgs.contains("-pix_fmt") {
                arguments += ["-pix_fmt", videoCfg.pixelFormat]
            }

            if (videoCodec == "hevc_videotoolbox" || videoCodec == "libx265") && !extraArgs.contains("-tag:v") && outputExtension.lowercased() == "mp4" {
                arguments += ["-tag:v", "hvc1"]
            }
        } else {
            // Audio-only input: disable video processing
            arguments += ["-vn"]
        }

        var note: String?
        if let targetSizeBytes {
            guard let duration, duration > 0 else { throw VideoConversionError.durationUnknown }
            if hasVideo {
                let bitrates = Self.computeBitrates(targetSizeBytes: targetSizeBytes, durationSeconds: duration, hasAudio: audioCodec != nil)
                arguments += Self.stripRateControlArgs(extraArgs)
                arguments += ["-b:v", "\(bitrates.videoBps)", "-maxrate", "\(Int(Double(bitrates.videoBps) * 1.45))", "-bufsize", "\(bitrates.videoBps * 2)"]
                if let audioCodec {
                    arguments += ["-c:a", audioCodec, "-b:a", "\(bitrates.audioBps)"]
                } else {
                    arguments += ["-an"]
                }
            } else {
                let totalBits = Double(targetSizeBytes) * 8 * 0.95
                let totalBps = Int(max(totalBits / duration, 32_000))
                if let audioCodec {
                    arguments += ["-c:a", audioCodec, "-b:a", "\(totalBps)"]
                }
            }
            note = "Targeted \(ByteSize.displayString(targetSizeBytes)) via estimated bitrate (single-pass, not exact)"
        } else {
            if hasVideo {
                if videoCodec.contains("videotoolbox") {
                    if videoCfg.encodingMode == "bitrate" && videoCfg.targetBitrateKbps > 0 {
                        arguments += ["-b:v", "\(videoCfg.targetBitrateKbps)k"]
                    } else {
                        arguments += ["-q:v", "65"]
                    }
                    arguments += Self.stripRateControlArgs(extraArgs)
                } else {
                    if videoCfg.encodingMode == "crf" && (videoCodec.contains("libx264") || videoCodec.contains("libx265") || videoCodec.contains("libsvtav1") || videoCodec.contains("libvpx")) {
                        arguments += ["-crf", "\(videoCfg.crfValue)"]
                        arguments += Self.stripRateControlArgs(extraArgs)
                    } else if videoCfg.encodingMode == "bitrate" && videoCfg.targetBitrateKbps > 0 {
                        arguments += ["-b:v", "\(videoCfg.targetBitrateKbps)k"]
                        arguments += Self.stripRateControlArgs(extraArgs)
                    } else {
                        arguments += extraArgs
                    }
                }
            }
            
            // Audio track selection
            if videoCfg.audioCodec == "none" {
                arguments += ["-an"]
            } else if videoCfg.audioCodec == "copy" {
                arguments += ["-c:a", "copy"]
            } else if let audioCodec {
                var chosenAudio = audioCodec
                if videoCfg.audioCodec != "auto" && videoCfg.audioCodec != "default" && !videoCfg.audioCodec.isEmpty {
                    let requested = videoCfg.audioCodec
                    let ext = outputExtension.lowercased()
                    let isCompatible: Bool
                    switch ext {
                    case "webm":
                        isCompatible = (requested == "opus" || requested == "vorbis")
                    case "mpg", "mpeg", "vob":
                        isCompatible = (requested == "mp2" || requested == "ac3" || requested == "mp3")
                    case "mxf", "dv":
                        isCompatible = requested.hasPrefix("pcm_")
                    case "wmv", "asf":
                        isCompatible = (requested == "wmav2")
                    default:
                        isCompatible = true
                    }
                    if isCompatible {
                        chosenAudio = requested
                    }
                }

                let actualAudioCodec = (chosenAudio == "opus") ? "libopus" : chosenAudio
                arguments += ["-c:a", actualAudioCodec]

                if !actualAudioCodec.hasPrefix("pcm_") {
                    arguments += ["-b:a", "\(videoCfg.audioBitrateKbps)k"]
                }
                if actualAudioCodec == "libopus" {
                    arguments += ["-ar", "48000"]
                } else if actualAudioCodec == "vorbis" {
                    arguments += ["-strict", "-2", "-ac", "2"]
                }
            } else {
                arguments += ["-an"]
            }
        }

        if hasVideo {
            // Framerate
            if videoCfg.frameRate != "keep" && !extraArgs.contains("-r") {
                arguments += ["-r", videoCfg.frameRate]
            }

            // Filters: Scaling & Deinterlacing
            var videoFilters: [String] = []
            if videoCfg.deinterlace {
                videoFilters.append("yadif")
            }

            if let vfIndex = arguments.firstIndex(of: "-vf"), vfIndex + 1 < arguments.count {
                var existingVF = arguments[vfIndex + 1]
                if let targetWidth, targetWidth > 0 {
                    if existingVF.contains("scale=480:-1") {
                        existingVF = existingVF.replacingOccurrences(of: "scale=480:-1", with: "scale=\(targetWidth):-2")
                    } else {
                        videoFilters.append("scale=\(targetWidth):-2:flags=\(videoCfg.scalingAlgorithm)")
                    }
                }
                if !videoFilters.isEmpty {
                    arguments[vfIndex + 1] = videoFilters.joined(separator: ",") + "," + existingVF
                } else {
                    arguments[vfIndex + 1] = existingVF
                }
            } else {
                if let targetWidth, targetWidth > 0 {
                    videoFilters.append("scale=\(targetWidth):-2:flags=\(videoCfg.scalingAlgorithm)")
                }
                if !videoFilters.isEmpty {
                    arguments += ["-vf", videoFilters.joined(separator: ",")]
                }
            }
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
            note = "\(note ?? "") - actual: \(ByteSize.displayString(size))"
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

    private func canStreamCopyRemux(
        sourceURL: URL,
        targetExtension: String,
        probe: MediaInfo?,
        videoCfg: VideoConfig,
        targetSizeBytes: Int64?,
        targetWidth: Int?
    ) -> Bool {
        guard targetSizeBytes == nil, targetWidth == nil else { return false }
        guard !videoCfg.deinterlace, videoCfg.frameRate == "keep" else { return false }
        guard videoCfg.audioCodec == "auto" || videoCfg.audioCodec == "default" || videoCfg.audioCodec == "copy" || videoCfg.audioCodec.isEmpty else { return false }
        
        let targetExt = targetExtension.lowercased()
        guard targetExt == "mp4" || targetExt == "m4v" || targetExt == "mov" else { return false }
        
        guard let probe, let vCodec = probe.videoCodec?.lowercased() else { return false }
        let isCompatibleVideo = vCodec == "h264" || vCodec == "hevc"
        guard isCompatibleVideo else { return false }
        
        if let aCodec = probe.audioCodec?.lowercased() {
            let isCompatibleAudio = aCodec == "aac" || aCodec == "mp3"
            guard isCompatibleAudio else { return false }
        }
        
        let sourceExt = sourceURL.pathExtension.lowercased()
        if sourceExt == targetExt { return false }
        
        return true
    }

    private static func stripRateControlArgs(_ args: [String]) -> [String] {
        var result: [String] = []
        var skipNext = false
        for arg in args {
            if skipNext {
                skipNext = false
                continue
            }
            if arg == "-b:v" || arg == "-crf" || arg == "-maxrate" || arg == "-bufsize" || arg == "-q:v" {
                skipNext = true
                continue
            }
            result.append(arg)
        }
        return result
    }
}
