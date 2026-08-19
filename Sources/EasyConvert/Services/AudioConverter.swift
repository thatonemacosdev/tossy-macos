import Foundation

struct AudioConversionResult {
    let outputURL: URL
    let note: String?
}

/// Converts audio via the bundled ffmpeg  -  covers everything from MP3/AAC/WAV/FLAC to the
/// Dolby/DTS-adjacent formats (AC3/E-AC3) and legacy codecs (WMA, AMR).
final class AudioConverter {
    private let ffmpeg = FFmpegService()

    /// When `targetSizeBytes` is set, bitrate-controllable formats (MP3/AAC/OGG/Opus/WMA/
    /// AC3/E-AC3/AMR) get an estimated `-b:a`; PCM-ish/lossless formats (WAV/FLAC/ALAC/CAF,
    /// which don't have a meaningful bitrate knob) instead have their sample rate reduced to
    /// fit, the audio equivalent of downscaling a lossless image.
    func convert(
        sourceURL: URL,
        to format: AudioFormat,
        quality: Double = 0.7,
        destinationFolder: URL? = nil,
        targetSizeBytes: Int64? = nil,
        customBaseName: String? = nil,
        preserveMetadata: Bool = true,
        onProgress: @escaping (Double) -> Void
    ) async throws -> AudioConversionResult {
        guard format.isAvailable else {
            throw VideoConversionError.formatUnavailable(format.unavailabilityReason ?? "This format isn't available.")
        }
        guard FFmpegLocator.isAvailable else {
            throw VideoConversionError.formatUnavailable("ffmpeg isn't available.")
        }

        let outputURL = OutputNaming.uniqueOutputURL(
            for: sourceURL,
            fileExtension: format.fileExtension,
            destinationFolder: destinationFolder,
            baseNameOverride: customBaseName
        )

        let mediaInfo = MediaProbe.probe(url: sourceURL)
        // Only reject when the probe positively found no audio stream (e.g. a silent video).
        // If probing itself was inconclusive, let ffmpeg attempt it and surface its own error.
        if let mediaInfo, mediaInfo.audioCodec == nil {
            throw VideoConversionError.noAudioTrack
        }
        let duration = mediaInfo?.durationSeconds
        let spec = format.ffmpegSpec

        var arguments = ["-y", "-i", sourceURL.path]

        if !preserveMetadata {
            arguments += ["-map_metadata", "-1"]
        }

        let audioCfg = AppSettings.shared.audioConfig
        var effectiveCodec = spec.codec

        // Handle Bit Depth for Lossless Formats
        if format == .wav || format == .caf {
            if audioCfg.losslessBitDepth == "24" {
                effectiveCodec = "pcm_s24le"
            } else if audioCfg.losslessBitDepth == "32" {
                effectiveCodec = "pcm_f32le"
            }
        } else if format == .aiff {
            if audioCfg.losslessBitDepth == "24" {
                effectiveCodec = "pcm_s24be"
            } else if audioCfg.losslessBitDepth == "32" {
                effectiveCodec = "pcm_f32be"
            }
        }

        arguments += ["-vn", "-c:a", effectiveCodec]
        arguments += spec.extraArgs

        // FLAC specific options
        if format == .flac {
            arguments += ["-compression_level", "\(audioCfg.flacCompressionLevel)"]
        }

        // Opus specific options
        if format == .opus {
            arguments += ["-application", audioCfg.opusApplication]
        }

        // Sample rate
        if format == .opus {
            let validOpusRates = ["8000", "12000", "16000", "24000", "48000"]
            let rate = validOpusRates.contains(audioCfg.sampleRateHz) ? audioCfg.sampleRateHz : "48000"
            arguments += ["-ar", rate]
        } else if audioCfg.sampleRateHz != "keep" && targetSizeBytes == nil {
            arguments += ["-ar", audioCfg.sampleRateHz]
        }

        // Channels
        if format == .ogg {
            arguments += ["-ac", "2"]
        } else if audioCfg.channels == "mono" {
            arguments += ["-ac", "1"]
        } else if audioCfg.channels == "stereo" || audioCfg.channels == "downmix51" {
            arguments += ["-ac", "2"]
        }

        // Audio Filters: Loudnorm
        if audioCfg.normalizeEBUR128 {
            arguments += ["-af", "loudnorm=I=-24:LRA=7:tp=-2"]
        }

        var note: String?
        if let targetSizeBytes {
            guard let duration, duration > 0 else { throw VideoConversionError.durationUnknown }
            let totalBps = Double(targetSizeBytes) * 8 * 0.95 / duration

            if isBitrateControllable(format) {
                let bitrateBps = max(Int(totalBps), 8_000)
                arguments += ["-b:a", "\(bitrateBps)"]
                note = "Targeted \(ByteSize.displayString(targetSizeBytes)) via estimated bitrate"
            } else {
                // Lossless/PCM: no bitrate knob, so reduce sample rate instead.
                let channels = 2
                let bytesPerSample = 2
                let sampleRate = max(8_000, min(48_000, Int(totalBps / Double(channels * bytesPerSample * 8))))
                arguments += ["-ar", "\(sampleRate)", "-ac", "\(channels)"]
                note = "Targeted \(ByteSize.displayString(targetSizeBytes)) by reducing sample rate to \(sampleRate)Hz"
            }
        } else if format.supportsQuality {
            if audioCfg.bitrateMode == "vbr" && format == .mp3 {
                arguments += ["-q:a", "\(audioCfg.vbrQuality)"]
            } else {
                let bitrateKbps = max(32, min(320, Int(64 + quality * 192)))
                arguments += ["-b:a", "\(bitrateKbps)k"]
            }
        }

        if let muxer = spec.muxer {
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
        return AudioConversionResult(outputURL: outputURL, note: note)
    }

    private func isBitrateControllable(_ format: AudioFormat) -> Bool {
        switch format {
        case .mp3, .aac, .m4a, .ogg, .opus, .wma, .ac3, .eac3, .amr: return true
        case .wav, .flac, .alac, .caf, .aiff: return false
        }
    }
}
