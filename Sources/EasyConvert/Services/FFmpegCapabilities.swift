import Foundation

/// Queries the bundled ffmpeg once for which encoders/decoders/muxers/demuxers it was actually
/// built with, and caches the result. Formats vary between ffmpeg builds (e.g. this build has
/// no JPEG XL or Farbfeld support), so we check reality instead of assuming a codec list.
final class FFmpegCapabilities {
    static let shared = FFmpegCapabilities()

    private(set) var encoders: Set<String> = []
    private(set) var decoders: Set<String> = []
    private(set) var muxers: Set<String> = []
    private(set) var demuxers: Set<String> = []

    private init() {
        guard let ffmpegPath = FFmpegLocator.ffmpegPath else { return }
        encoders = Self.parseCodecList(FFmpegService.runCapturingOutput(executablePath: ffmpegPath, arguments: ["-hide_banner", "-encoders"]))
        decoders = Self.parseCodecList(FFmpegService.runCapturingOutput(executablePath: ffmpegPath, arguments: ["-hide_banner", "-decoders"]))
        muxers = Self.parseFormatList(FFmpegService.runCapturingOutput(executablePath: ffmpegPath, arguments: ["-hide_banner", "-muxers"]))
        demuxers = Self.parseFormatList(FFmpegService.runCapturingOutput(executablePath: ffmpegPath, arguments: ["-hide_banner", "-demuxers"]))
    }

    func canEncode(_ name: String) -> Bool { encoders.contains(name) }
    func canDecode(_ name: String) -> Bool { decoders.contains(name) }
    func canMux(_ name: String) -> Bool { muxers.contains(name) }
    func canDemux(_ name: String) -> Bool { demuxers.contains(name) }

    /// Lines look like " V....D libx264              libx264 H.264 ..." — the second token is the name.
    private static func parseCodecList(_ output: String) -> Set<String> {
        var names: Set<String> = []
        for line in output.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.first == "V" || trimmed.first == "A" || trimmed.first == "S" else { continue }
            let parts = trimmed.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
            guard parts.count >= 2 else { continue }
            names.insert(String(parts[1]))
        }
        return names
    }

    /// Lines look like "  E  matroska        Matroska" or "  D   avi  AVI (...)" — name is the
    /// first non-flag token.
    private static func parseFormatList(_ output: String) -> Set<String> {
        var names: Set<String> = []
        for line in output.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.first == "E" || trimmed.first == "D" else { continue }
            let parts = trimmed.split(separator: " ", omittingEmptySubsequences: true)
            guard parts.count >= 2 else { continue }
            names.insert(String(parts[1]))
        }
        return names
    }
}
