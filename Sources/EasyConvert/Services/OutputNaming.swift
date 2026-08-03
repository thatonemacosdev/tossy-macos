import Foundation

enum OutputNaming {
    /// Picks a non-colliding output URL for `sourceURL` converted to `fileExtension`,
    /// placed in `destinationFolder` (or alongside the source if `nil`).
    static func uniqueOutputURL(for sourceURL: URL, fileExtension: String, destinationFolder: URL?, nameSuffix: String = "") -> URL {
        let folder = destinationFolder ?? sourceURL.deletingLastPathComponent()
        let baseName = sourceURL.deletingPathExtension().lastPathComponent + nameSuffix
        var candidate = folder.appendingPathComponent(baseName).appendingPathExtension(fileExtension)

        var counter = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = folder.appendingPathComponent("\(baseName)-\(counter)").appendingPathExtension(fileExtension)
            counter += 1
        }
        return candidate
    }
}
