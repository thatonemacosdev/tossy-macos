import Foundation

struct AudioConversionResult {
    let outputURL: URL
    let note: String?
}

/// Converts audio via the bundled ffmpeg — covers everything from MP3/AAC/WAV/FLAC to the
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
        quality: Double,
        destinationFolder: URL?,
        targetSizeBytes: Int64? = nil,
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
            destinationFolder: destinationFolder
        )

        let duration = MediaProbe.probe(url: sourceURL)?.durationSeconds
        let spec = format.ffmpegSpec

        var arguments = ["-y", "-i", sourceURL.path, "-vn", "-c:a", spec.codec]
        arguments += spec.extraArgs

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
            let bitrateKbps = Int(64 + quality * 192)
            arguments += ["-b:a", "\(bitrateKbps)k"]
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
            note = "\(note ?? "") — actual: \(ByteSize.displayString(size))"
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
