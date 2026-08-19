import AVFoundation
import UniformTypeIdentifiers

enum VideoBackend {
    /// Hardware-accelerated via VideoToolbox, through AVFoundation's AVAssetExportSession.
    case avFoundation(preset: String)
    /// Routed through the bundled ffmpeg. `muxer` forces the container when the file
    /// extension alone wouldn't tell ffmpeg what to use (e.g. .mts/.m2ts).
    case ffmpeg(muxer: String?, videoCodec: String, audioCodec: String?, extraArgs: [String])
    /// Uses ffmpeg frame extraction + img2webp assembler.
    case animatedWebp
}

enum VideoCategory: String, CaseIterable {
    case common = "Common"
    case professional = "Professional"
    case animation = "Animation"
}

enum VideoFormat: String, CaseIterable, Identifiable {
    case mp4H264, mp4Hevc, movH264, movHevc, movProRes422
    case mkv, webm, avi, flv, mpeg, ts, mts, m2ts, ogv, threeGp, asf, mxf, f4v, vob, dv, nut
    case webmVp8, webmVp9, mp4Av1, mpeg2, mpeg4Part2
    case dnxhd, dnxhr
    case animatedGif, animatedWebp

    var id: String { rawValue }

    var category: VideoCategory {
        switch self {
        case .dnxhd, .dnxhr, .movProRes422: return .professional
        case .animatedGif, .animatedWebp: return .animation
        default: return .common
        }
    }

    var displayName: String {
        switch self {
        case .mp4H264: return "MP4 (H.264)"
        case .mp4Hevc: return "MP4 (HEVC)"
        case .movH264: return "MOV (H.264)"
        case .movHevc: return "MOV (HEVC)"
        case .movProRes422: return "MOV (ProRes 422)"
        case .mkv: return "MKV (H.264 + AAC)"
        case .webm: return "WebM (VP9 + Opus)"
        case .avi: return "AVI (H.264 + AAC)"
        case .flv: return "FLV (H.264 + AAC)"
        case .mpeg: return "MPEG (MPEG-2)"
        case .ts: return "TS (MPEG-TS, H.264)"
        case .mts: return "MTS (AVCHD, H.264)"
        case .m2ts: return "M2TS (H.264)"
        case .ogv: return "OGV (Theora + Vorbis)"
        case .threeGp: return "3GP (H.264 + AAC)"
        case .asf: return "ASF/WMV (WMV2 + WMA)"
        case .mxf: return "MXF (MPEG-2, broadcast)"
        case .f4v: return "F4V (H.264 + AAC)"
        case .vob: return "VOB (DVD, MPEG-2)"
        case .dv: return "DV"
        case .nut: return "NUT (H.264)"
        case .webmVp8: return "WebM (VP8 + Vorbis)"
        case .webmVp9: return "WebM (VP9 + Opus)"
        case .mp4Av1: return "MP4 (AV1)"
        case .mpeg2: return "MPEG-2 (.mpg)"
        case .mpeg4Part2: return "AVI (MPEG-4 Part 2)"
        case .dnxhd: return "MOV (DNxHD)"
        case .dnxhr: return "MOV (DNxHR HQ)"
        case .animatedGif: return "Animated GIF"
        case .animatedWebp: return "Animated WebP"
        }
    }

    var fileExtension: String {
        switch self {
        case .mp4H264, .mp4Hevc, .mp4Av1: return "mp4"
        case .movH264, .movHevc, .movProRes422, .dnxhd, .dnxhr: return "mov"
        case .mkv: return "mkv"
        case .webm, .webmVp8, .webmVp9: return "webm"
        case .avi, .mpeg4Part2: return "avi"
        case .flv: return "flv"
        case .mpeg, .mpeg2: return "mpg"
        case .ts: return "ts"
        case .mts: return "mts"
        case .m2ts: return "m2ts"
        case .ogv: return "ogv"
        case .threeGp: return "3gp"
        case .asf: return "wmv"
        case .mxf: return "mxf"
        case .f4v: return "f4v"
        case .vob: return "vob"
        case .dv: return "dv"
        case .nut: return "nut"
        case .animatedGif: return "gif"
        case .animatedWebp: return "webp"
        }
    }

    var backend: VideoBackend {
        switch self {
        case .mp4H264, .movH264: return .avFoundation(preset: AVAssetExportPresetHighestQuality)
        case .mp4Hevc, .movHevc: return .avFoundation(preset: AVAssetExportPresetHEVCHighestQuality)
        case .movProRes422: return .avFoundation(preset: AVAssetExportPresetAppleProRes422LPCM)

        case .mkv: return .ffmpeg(muxer: nil, videoCodec: "libx264", audioCodec: "aac", extraArgs: [])
        case .webm, .webmVp9: return .ffmpeg(muxer: nil, videoCodec: "libvpx-vp9", audioCodec: "libopus", extraArgs: [])
        // ffmpeg's native vorbis encoder only supports stereo output; force it regardless of source.
        case .webmVp8: return .ffmpeg(muxer: nil, videoCodec: "libvpx", audioCodec: "vorbis", extraArgs: ["-strict", "-2", "-ac", "2"])
        case .avi: return .ffmpeg(muxer: nil, videoCodec: "libx264", audioCodec: "aac", extraArgs: [])
        case .flv: return .ffmpeg(muxer: nil, videoCodec: "libx264", audioCodec: "aac", extraArgs: [])
        case .mpeg, .mpeg2: return .ffmpeg(muxer: nil, videoCodec: "mpeg2video", audioCodec: "mp2", extraArgs: [])
        case .ts: return .ffmpeg(muxer: "mpegts", videoCodec: "libx264", audioCodec: "aac", extraArgs: [])
        case .mts, .m2ts: return .ffmpeg(muxer: "mpegts", videoCodec: "libx264", audioCodec: "aac", extraArgs: [])
        case .ogv: return .ffmpeg(muxer: nil, videoCodec: "libtheora", audioCodec: "vorbis", extraArgs: ["-strict", "-2", "-ac", "2"])
        case .threeGp: return .ffmpeg(muxer: nil, videoCodec: "libx264", audioCodec: "aac", extraArgs: ["-profile:v", "baseline", "-pix_fmt", "yuv420p"])
        case .asf: return .ffmpeg(muxer: "asf", videoCodec: "wmv2", audioCodec: "wmav2", extraArgs: [])
        case .mxf: return .ffmpeg(muxer: nil, videoCodec: "mpeg2video", audioCodec: "pcm_s16le", extraArgs: ["-ar", "48000"])
        case .f4v: return .ffmpeg(muxer: "mp4", videoCodec: "libx264", audioCodec: "aac", extraArgs: [])
        case .vob: return .ffmpeg(muxer: "dvd", videoCodec: "mpeg2video", audioCodec: "ac3", extraArgs: [])
        // DV is a fixed-format codec: only 720x480@29.97 (NTSC, yuv411p) or 720x576@25 (PAL) are
        // valid: anything else fails to open. Force NTSC dimensions/rate/pixel format/sample rate.
        case .dv: return .ffmpeg(muxer: nil, videoCodec: "dvvideo", audioCodec: "pcm_s16le", extraArgs: ["-vf", "scale=720:480,setdar=4/3", "-r", "29.97", "-pix_fmt", "yuv411p", "-ar", "48000", "-ac", "2"])
        case .nut: return .ffmpeg(muxer: nil, videoCodec: "libx264", audioCodec: "aac", extraArgs: [])
        case .mp4Av1: return .ffmpeg(muxer: nil, videoCodec: "libsvtav1", audioCodec: "aac", extraArgs: [])
        case .mpeg4Part2: return .ffmpeg(muxer: nil, videoCodec: "mpeg4", audioCodec: "libmp3lame", extraArgs: [])
        // DNxHD (unlike DNxHR) only accepts specific resolution/framerate/bitrate combos -
        // force a valid one (1080p25 @ 36Mbps) rather than fail on arbitrary source dimensions.
        case .dnxhd: return .ffmpeg(muxer: nil, videoCodec: "dnxhd", audioCodec: "pcm_s16le", extraArgs: ["-vf", "scale=1920:1080", "-r", "25", "-pix_fmt", "yuv422p", "-b:v", "36M", "-ar", "48000"])
        case .dnxhr: return .ffmpeg(muxer: nil, videoCodec: "dnxhd", audioCodec: "pcm_s16le", extraArgs: ["-profile:v", "dnxhr_hq", "-pix_fmt", "yuv422p"])
        case .animatedGif:
            return .ffmpeg(
                muxer: nil,
                videoCodec: "gif",
                audioCodec: nil,
                extraArgs: [
                    "-vf", "fps=15,scale=480:-1:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse",
                    "-loop", "0"
                ]
            )
        case .animatedWebp:
            return .animatedWebp
        }
    }

    var isAvailable: Bool {
        switch backend {
        case .avFoundation:
            return true
        case .ffmpeg(_, let videoCodec, let audioCodec, _):
            guard FFmpegLocator.isAvailable, FFmpegCapabilities.shared.canEncode(videoCodec) else { return false }
            if let audioCodec { return FFmpegCapabilities.shared.canEncode(audioCodec) }
            return true
        case .animatedWebp:
            return FFmpegLocator.isAvailable && WebPLocator.img2webpPath != nil
        }
    }

    var unavailabilityReason: String? {
        guard !isAvailable else { return nil }
        return "This build of ffmpeg wasn't compiled with \(displayName) support."
    }

    var fileType: AVFileType? {
        switch self {
        case .mp4H264, .mp4Hevc: return .mp4
        case .movH264, .movHevc, .movProRes422: return .mov
        default: return nil
        }
    }

    /// Hardware-accelerated (VideoToolbox) export preset, for AVFoundation-backed formats.
    var exportPreset: String? {
        if case .avFoundation(let preset) = backend { return preset }
        return nil
    }

    /// Umbrella type covering everything AVFoundation/ffmpeg can read (mp4, mov, mkv, webm,
    /// avi, and essentially any other container ffmpeg demuxes).
    static let readableContentTypes: [UTType] = [.movie, .audiovisualContent]

    static let readableExtensions: Set<String> = [
        "mp4", "mov", "m4v", "mkv", "webm", "avi", "flv", "mpg", "mpeg",
        "ts", "mts", "m2ts", "ogv", "3gp", "wmv", "asf", "mxf", "f4v",
        "vob", "dv", "nut"
    ]
}
