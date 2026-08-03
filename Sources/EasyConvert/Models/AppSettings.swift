import Foundation

@Observable
final class AppSettings {
    static let shared = AppSettings()

    /// `nil` means no limit. Defaults to 4GB — generous for everyday files, but cheap
    /// insurance against accidentally queuing something enormous.
    var maxFileSizeBytes: Int64? = 4_000_000_000

    static let sizePresets: [(label: String, bytes: Int64?)] = [
        ("500 MB", 500_000_000),
        ("1 GB", 1_000_000_000),
        ("4 GB", 4_000_000_000),
        ("16 GB", 16_000_000_000),
        ("No limit", nil)
    ]
}

enum FeasibilityChecker {
    private static let formatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter
    }()

    /// Returns a human-readable warning if `url` exceeds the configured size limit, else `nil`.
    static func checkFileSize(_ url: URL) -> String? {
        guard let limit = AppSettings.shared.maxFileSizeBytes else { return nil }
        guard let size = try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64 else { return nil }
        guard size > limit else { return nil }
        return "File is \(formatter.string(fromByteCount: size)), which exceeds the \(formatter.string(fromByteCount: limit)) limit."
    }
}
