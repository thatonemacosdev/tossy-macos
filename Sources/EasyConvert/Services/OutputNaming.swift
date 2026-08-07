import Foundation

enum OutputNaming {
    // Image jobs can run concurrently (ContentView.convertAll uses a TaskGroup), so two jobs
    // picking a name at the same instant could both see the same path as free via fileExists
    // and collide, especially with a shared custom filename. This lock plus an in-memory
    // registry of already-handed-out paths closes that window without touching the filesystem
    // (which would break AVAssetExportSession — it refuses to export if the destination
    // already exists, even as an empty placeholder).
    private static let lock = NSLock()
    private static var claimedPaths = Set<String>()

    /// Picks a non-colliding output URL for `sourceURL` converted to `fileExtension`,
    /// placed in `destinationFolder` (or alongside the source if `nil`). Pass `baseNameOverride`
    /// for a custom output filename instead of the one derived from `sourceURL`.
    static func uniqueOutputURL(for sourceURL: URL, fileExtension: String, destinationFolder: URL?, nameSuffix: String = "", baseNameOverride: String? = nil) -> URL {
        let folder = destinationFolder ?? sourceURL.deletingLastPathComponent()
        let baseName = (baseNameOverride ?? sourceURL.deletingPathExtension().lastPathComponent) + nameSuffix

        lock.lock()
        defer { lock.unlock() }

        var candidate = folder.appendingPathComponent(baseName).appendingPathExtension(fileExtension)
        var counter = 2
        while FileManager.default.fileExists(atPath: candidate.path) || claimedPaths.contains(candidate.path) {
            candidate = folder.appendingPathComponent("\(baseName)-\(counter)").appendingPathExtension(fileExtension)
            counter += 1
        }
        claimedPaths.insert(candidate.path)
        return candidate
    }
}
