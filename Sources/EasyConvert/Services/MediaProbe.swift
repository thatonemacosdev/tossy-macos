import Foundation

struct MediaInfo {
    let durationSeconds: Double?
    let videoCodec: String?
    let audioCodec: String?
    let width: Int?
    let height: Int?
}

enum MediaProbe {
    static func probe(url: URL) -> MediaInfo? {
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
                        // Duration formatted like HH:MM:SS.mmmmmm
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
