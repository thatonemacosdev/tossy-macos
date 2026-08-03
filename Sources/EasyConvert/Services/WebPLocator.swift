import Foundation

/// Locates the bundled `cwebp`/`dwebp`/`img2webp` (Google's reference WebP tools) —
/// this ffmpeg build wasn't compiled with a WebP encoder, so we use the canonical tool instead.
enum WebPLocator {
    static let cwebpPath: String? = locate(binaryName: "cwebp")
    static let dwebpPath: String? = locate(binaryName: "dwebp")
    static let img2webpPath: String? = locate(binaryName: "img2webp")

    private static func locate(binaryName: String) -> String? {
        var candidates: [String] = []
        if let resourceURL = Bundle.main.resourceURL {
            candidates.append(resourceURL.appendingPathComponent("webp/\(binaryName)").path)
        }
        candidates.append(contentsOf: [
            "/opt/homebrew/bin/\(binaryName)",
            "/usr/local/bin/\(binaryName)"
        ])
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }
}
