import Foundation

/// Locates the bundled `cjxl`/`djxl` (the JPEG XL reference tools)  -  this ffmpeg build has
/// no JPEG XL support compiled in, so we use the canonical encoder/decoder instead.
enum JXLLocator {
    static let cjxlPath: String? = locate(binaryName: "cjxl")
    static let djxlPath: String? = locate(binaryName: "djxl")

    private static func locate(binaryName: String) -> String? {
        var candidates: [String] = []
        if let resourceURL = Bundle.main.resourceURL {
            candidates.append(resourceURL.appendingPathComponent("jxl/\(binaryName)").path)
        }
        candidates.append(contentsOf: [
            "/opt/homebrew/bin/\(binaryName)",
            "/usr/local/bin/\(binaryName)"
        ])
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }
}
