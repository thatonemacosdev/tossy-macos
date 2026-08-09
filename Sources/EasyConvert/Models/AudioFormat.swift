import UniformTypeIdentifiers

enum AudioFormat: String, CaseIterable, Identifiable {
    case mp3, aac, m4a, wav, flac, alac, aiff, ogg, opus, wma, ac3, eac3, amr, caf

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .mp3: return "MP3"
        case .aac: return "AAC"
        case .m4a: return "M4A (AAC)"
        case .wav: return "WAV"
        case .flac: return "FLAC"
        case .alac: return "ALAC (Apple Lossless)"
        case .aiff: return "AIFF"
        case .ogg: return "OGG (Vorbis)"
        case .opus: return "Opus"
        case .wma: return "WMA"
        case .ac3: return "AC3 (Dolby Digital)"
        case .eac3: return "E-AC3 (Dolby Digital Plus)"
        case .amr: return "AMR"
        case .caf: return "CAF (Apple Core Audio)"
        }
    }

    var fileExtension: String {
        switch self {
        case .mp3: return "mp3"
        case .aac: return "aac"
        case .m4a: return "m4a"
        case .wav: return "wav"
        case .flac: return "flac"
        case .alac: return "m4a"
        case .aiff: return "aiff"
        case .ogg: return "ogg"
        case .opus: return "opus"
        case .wma: return "wma"
        case .ac3: return "ac3"
        case .eac3: return "eac3"
        case .amr: return "amr"
        case .caf: return "caf"
        }
    }

    /// (muxer override, codec name, extra ffmpeg args)
    var ffmpegSpec: (muxer: String?, codec: String, extraArgs: [String]) {
        switch self {
        case .mp3: return (nil, "libmp3lame", [])
        case .aac: return ("adts", "aac", [])
        case .m4a: return ("ipod", "aac", [])
        case .wav: return (nil, "pcm_s16le", [])
        case .flac: return (nil, "flac", [])
        case .alac: return ("ipod", "alac", [])
        case .aiff: return (nil, "pcm_s16be", [])
        // ffmpeg's native vorbis encoder only supports stereo output; force it regardless of source.
        case .ogg: return (nil, "vorbis", ["-strict", "-2", "-ac", "2"])
        case .opus: return (nil, "libopus", [])
        case .wma: return ("asf", "wmav2", [])
        case .ac3: return (nil, "ac3", [])
        case .eac3: return (nil, "eac3", [])
        case .amr: return (nil, "libopencore_amrnb", ["-ar", "8000", "-ac", "1"])
        case .caf: return (nil, "pcm_s16le", [])
        }
    }

    var supportsQuality: Bool {
        switch self {
        case .mp3, .aac, .m4a, .ogg, .opus: return true
        default: return false
        }
    }

    var isAvailable: Bool {
        FFmpegLocator.isAvailable && FFmpegCapabilities.shared.canEncode(ffmpegSpec.codec)
    }

    var unavailabilityReason: String? {
        guard !isAvailable else { return nil }
        return "This build of ffmpeg wasn't compiled with \(displayName) support."
    }

    /// Everything ffmpeg can demux as audio (mp3, wav, aac, wma, etc), plus video containers —
    /// dropping a video file here rips its audio track rather than requiring a detour through
    /// the Video tab first.
    static let readableContentTypes: [UTType] = [.audio, .movie, .audiovisualContent]

    /// Maps a source file's extension back to one of our writable formats — used by
    /// "keep original format" (recompress in place without converting).
    static func matching(sourceURL: URL) -> AudioFormat? {
        switch sourceURL.pathExtension.lowercased() {
        case "mp3": return .mp3
        case "aac": return .aac
        case "m4a": return .m4a
        case "wav", "wave": return .wav
        case "flac": return .flac
        case "aiff", "aif": return .aiff
        case "ogg": return .ogg
        case "opus": return .opus
        case "wma": return .wma
        case "ac3": return .ac3
        case "eac3": return .eac3
        case "amr": return .amr
        case "caf": return .caf
        default: return nil
        }
    }
}
