import Foundation

enum FormatCategory: String, CaseIterable, Identifiable, Sendable {
    case image = "Image"
    case video = "Video"
    case audio = "Audio"
    case document = "Document"
    case archive = "Archive"

    var id: String { rawValue }
}

struct ConversionOutput: Sendable {
    let outputURLs: [URL]
    let summaryNote: String?
}

protocol FormatConvertible: Sendable {
    var rawExtension: String { get }
    var category: FormatCategory { get }
    var displayName: String { get }
}

final class FormatRegistry: Sendable {
    static let shared = FormatRegistry()
    private init() {}

    func category(forExtension ext: String) -> FormatCategory? {
        let lower = ext.lowercased()
        if ImageFormat(rawValue: lower) != nil || ["svg", "ai", "eps", "raw", "cr2", "cr3", "nef", "arw", "dng"].contains(lower) {
            return .image
        }
        if VideoFormat(rawValue: lower) != nil || ["mp4", "mov", "m4v", "mkv", "webm", "avi", "flv", "ts", "mts", "wmv", "m4r"].contains(lower) {
            return .video
        }
        if AudioFormat(rawValue: lower) != nil || ["mp3", "m4a", "wav", "flac", "aac", "ogg", "opus", "aiff", "alac"].contains(lower) {
            return .audio
        }
        if ["pdf", "docx", "rtf", "odt", "txt", "md", "html", "srt", "vtt", "json", "plist", "csv", "yaml", "yml"].contains(lower) {
            return .document
        }
        if ["zip", "tar", "gz", "tgz", "bz2", "tbz2", "xz", "txz", "zst"].contains(lower) {
            return .archive
        }
        return nil
    }
}
