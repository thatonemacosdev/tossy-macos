import Foundation

/// Queries the bundled ffmpeg once for which encoders/decoders/muxers/demuxers it was actually
/// built with, and caches the result. Formats vary between ffmpeg builds (e.g. this build has
/// no JPEG XL or Farbfeld support), so we check reality instead of assuming a codec list.
final class FFmpegCapabilities: @unchecked Sendable {
    static let shared = FFmpegCapabilities()

    private let lock = NSLock()
    private var _encoders: Set<String> = defaultEncoders
    private var _decoders: Set<String> = defaultDecoders
    private var _muxers: Set<String> = defaultMuxers
    private var _demuxers: Set<String> = defaultDemuxers

    var encoders: Set<String> { lock.lock(); defer { lock.unlock() }; return _encoders }
    var decoders: Set<String> { lock.lock(); defer { lock.unlock() }; return _decoders }
    var muxers: Set<String> { lock.lock(); defer { lock.unlock() }; return _muxers }
    var demuxers: Set<String> { lock.lock(); defer { lock.unlock() }; return _demuxers }

    private static let defaultEncoders: Set<String> = [
        "libx264", "libx264rgb", "h264_videotoolbox", "libx265", "hevc_videotoolbox",
        "libvpx", "libvpx-vp9", "libsvtav1", "prores", "prores_ks", "prores_videotoolbox",
        "gif", "png", "ppm", "qoi", "hdr", "tiff", "bmp", "mjpeg",
        "aac", "libmp3lame", "libopus", "flac", "pcm_s16le", "pcm_s24le", "alac", "vorbis"
    ]
    private static let defaultDecoders: Set<String> = [
        "h264", "hevc", "vp8", "vp9", "av1", "prores", "gif", "png", "mjpeg", "hdr",
        "aac", "mp3", "opus", "flac", "pcm_s16le", "vorbis"
    ]
    private static let defaultMuxers: Set<String> = [
        "mp4", "mov", "matroska", "webm", "gif", "mp3", "flac", "wav", "ogg", "aac"
    ]
    private static let defaultDemuxers: Set<String> = [
        "mp4", "mov", "matroska", "webm", "gif", "mp3", "flac", "wav", "ogg", "aac", "avi"
    ]

    private init() {
        // Query live binary in background without blocking main thread or pumping RunLoop
        guard let ffmpegPath = FFmpegLocator.ffmpegPath else { return }
        Task.detached(priority: .utility) { [weak self] in
            let enc = Self.parseCodecList(FFmpegService.runCapturingOutput(executablePath: ffmpegPath, arguments: ["-hide_banner", "-encoders"]))
            let dec = Self.parseCodecList(FFmpegService.runCapturingOutput(executablePath: ffmpegPath, arguments: ["-hide_banner", "-decoders"]))
            let mux = Self.parseFormatList(FFmpegService.runCapturingOutput(executablePath: ffmpegPath, arguments: ["-hide_banner", "-muxers"]))
            let demux = Self.parseFormatList(FFmpegService.runCapturingOutput(executablePath: ffmpegPath, arguments: ["-hide_banner", "-demuxers"]))

            self?.updateCapabilities(encoders: enc, decoders: dec, muxers: mux, demuxers: demux)
        }
    }

    private func updateCapabilities(encoders enc: Set<String>, decoders dec: Set<String>, muxers mux: Set<String>, demuxers demux: Set<String>) {
        lock.lock()
        defer { lock.unlock() }
        if !enc.isEmpty { self._encoders = enc }
        if !dec.isEmpty { self._decoders = dec }
        if !mux.isEmpty { self._muxers = mux }
        if !demux.isEmpty { self._demuxers = demux }
    }

    func canEncode(_ name: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return _encoders.contains(name)
    }

    func canDecode(_ name: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return _decoders.contains(name)
    }

    func canMux(_ name: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return _muxers.contains(name)
    }

    func canDemux(_ name: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return _demuxers.contains(name)
    }

    /// Lines look like " V....D libx264              libx264 H.264 ..."  -  the second token is the name.
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

    /// Lines look like "  E  matroska        Matroska" or "  D   avi  AVI (...)"  -  name is the
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
