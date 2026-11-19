import Foundation
import AVFoundation

struct MediaInfo {
    let durationSeconds: Double?
    let videoCodec: String?
    let audioCodec: String?
    let width: Int?
    let height: Int?
}

enum MediaProbe {
    private static let appleNativeExtensions: Set<String> = [
        "mp4", "mov", "m4v", "m4a", "mp3", "wav", "aac", "aiff", "caf"
    ]

    static func probe(url: URL) -> MediaInfo? {
        let ext = url.pathExtension.lowercased()
        if appleNativeExtensions.contains(ext) {
            if let nativeInfo = probeViaAVFoundation(url: url) {
                return nativeInfo
            }
        }
        return probeViaFFprobe(url: url)
    }

    private static func probeViaAVFoundation(url: URL) -> MediaInfo? {
        let asset = AVURLAsset(url: url)
        let durationSeconds: Double? = asset.duration.seconds.isFinite && asset.duration.seconds > 0 ? asset.duration.seconds : nil

        var videoCodec: String?
        var audioCodec: String?
        var width: Int?
        var height: Int?

        let videoTracks = asset.tracks(withMediaType: .video)
        if let videoTrack = videoTracks.first {
            let size = videoTrack.naturalSize.applying(videoTrack.preferredTransform)
            width = max(1, Int(abs(size.width)))
            height = max(1, Int(abs(size.height)))

            if let desc = videoTrack.formatDescriptions.first {
                let subType = CMFormatDescriptionGetMediaSubType(desc as! CMFormatDescription)
                videoCodec = fourCCToString(subType)
            } else {
                videoCodec = "h264"
            }
        }

        let audioTracks = asset.tracks(withMediaType: .audio)
        if let audioTrack = audioTracks.first {
            if let desc = audioTrack.formatDescriptions.first {
                let subType = CMFormatDescriptionGetMediaSubType(desc as! CMFormatDescription)
                audioCodec = fourCCToString(subType)
            } else {
                audioCodec = "aac"
            }
        }

        guard videoCodec != nil || audioCodec != nil || durationSeconds != nil else {
            return nil
        }

        return MediaInfo(durationSeconds: durationSeconds, videoCodec: videoCodec, audioCodec: audioCodec, width: width, height: height)
    }

    private static func fourCCToString(_ code: FourCharCode) -> String {
        switch code {
        case kCMVideoCodecType_H264: return "h264"
        case kCMVideoCodecType_HEVC: return "hevc"
        case kCMVideoCodecType_AppleProRes422, kCMVideoCodecType_AppleProRes422HQ, kCMVideoCodecType_AppleProRes4444: return "prores"
        case kAudioFormatMPEG4AAC: return "aac"
        case kAudioFormatMPEGLayer3: return "mp3"
        case kAudioFormatLinearPCM: return "pcm"
        case kAudioFormatAppleLossless: return "alac"
        case kAudioFormatFLAC: return "flac"
        default:
            let bytes: [CChar] = [
                CChar((code >> 24) & 0xff),
                CChar((code >> 16) & 0xff),
                CChar((code >> 8) & 0xff),
                CChar(code & 0xff),
                0
            ]
            let raw = String(cString: bytes).trimmingCharacters(in: .whitespaces).lowercased()
            if raw == "avc1" { return "h264" }
            if raw == "hvc1" || raw == "hev1" { return "hevc" }
            return raw.isEmpty ? "unknown" : raw
        }
    }

    private static func probeViaFFprobe(url: URL) -> MediaInfo? {
        guard let ffprobePath = FFmpegLocator.ffprobePath else { return nil }
        let output = FFmpegService.runCapturingOutput(executablePath: ffprobePath, arguments: [
            "-v", "error",
            "-show_entries", "format=duration:stream=codec_type,codec_name,width,height",
            "-of", "json",
            url.path
        ])
        guard let data = output.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        var duration: Double?
        if let format = json["format"] as? [String: Any], let durationString = format["duration"] as? String {
            duration = Double(durationString)
        }

        var videoCodec: String?
        var audioCodec: String?
        var width: Int?
        var height: Int?
        if let streams = json["streams"] as? [[String: Any]] {
            for stream in streams {
                let type = stream["codec_type"] as? String
                if type == "video", videoCodec == nil {
                    videoCodec = stream["codec_name"] as? String
                    width = stream["width"] as? Int
                    height = stream["height"] as? Int
                } else if type == "audio", audioCodec == nil {
                    audioCodec = stream["codec_name"] as? String
                }

                if duration == nil {
                    if let durStr = stream["duration"] as? String, let d = Double(durStr), d > 0 {
                        duration = d
                    } else if let tags = stream["tags"] as? [String: Any],
                              let tagDur = (tags["DURATION"] ?? tags["duration"]) as? String {
                        let parts = tagDur.components(separatedBy: ":")
                        if parts.count == 3,
                           let h = Double(parts[0]),
                           let m = Double(parts[1]),
                           let s = Double(parts[2]) {
                            duration = h * 3600 + m * 60 + s
                        }
                    }
                }
            }
        }

        return MediaInfo(durationSeconds: duration, videoCodec: videoCodec, audioCodec: audioCodec, width: width, height: height)
    }
}

extension MediaInfo {
    var hasAudio: Bool {
        audioCodec != nil && !(audioCodec?.isEmpty ?? true)
    }
    
    var hasVideo: Bool {
        videoCodec != nil && !(videoCodec?.isEmpty ?? true)
    }
}
