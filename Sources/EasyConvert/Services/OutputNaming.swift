import Foundation

enum OutputNaming {
    /// Picks a non-colliding output URL for `sourceURL` converted to `fileExtension`,
    /// placed in `destinationFolder` (or alongside the source if `nil`). Pass `baseNameOverride`
    /// for a custom output filename instead of the one derived from `sourceURL`.
    static func uniqueOutputURL(for sourceURL: URL, fileExtension: String, destinationFolder: URL?, nameSuffix: String = "", baseNameOverride: String? = nil) -> URL {
        let folder = destinationFolder ?? sourceURL.deletingLastPathComponent()
        let baseName = (baseNameOverride ?? sourceURL.deletingPathExtension().lastPathComponent) + nameSuffix
        var candidate = folder.appendingPathComponent(baseName).appendingPathExtension(fileExtension)

        var counter = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = folder.appendingPathComponent("\(baseName)-\(counter)").appendingPathExtension(fileExtension)
            counter += 1
        }
        return candidate
    }
}
