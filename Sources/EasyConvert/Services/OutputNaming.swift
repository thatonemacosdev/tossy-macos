import Foundation

enum OutputNaming {
    // Image jobs can run concurrently (ContentView.convertAll uses a TaskGroup), so two jobs
    // picking a name at the same instant could both see the same path as free via fileExists
    // and collide, especially with a shared custom filename. This lock plus an in-memory
    // registry of already-handed-out paths closes that window without touching the filesystem
    // (which would break AVAssetExportSession: it refuses to export if the destination
    // already exists, even as an empty placeholder).
    private static let lock = NSLock()
    private static var claimedPaths = Set<String>()

    static func resetClaimedPaths() {
        lock.lock()
        defer { lock.unlock() }
        claimedPaths.removeAll()
    }

    /// Picks a non-colliding output URL for `sourceURL` converted to `fileExtension`,
    /// placed in `destinationFolder` (or alongside the source if `nil`). Pass `baseNameOverride`
    /// for a custom output filename instead of the one derived from `sourceURL`.
    static func uniqueOutputURL(for sourceURL: URL, fileExtension: String, destinationFolder: URL?, nameSuffix: String = "", baseNameOverride: String? = nil) -> URL {
        let folder = destinationFolder ?? sourceURL.deletingLastPathComponent()
        let rawBaseName = baseNameOverride ?? sourceURL.deletingPathExtension().lastPathComponent
        let formattedBaseName: String
        if baseNameOverride != nil {
            formattedBaseName = rawBaseName
        } else {
            switch AppSettings.shared.namingTemplate {
            case .standard:
                formattedBaseName = rawBaseName
            case .suffixFormat:
                formattedBaseName = "\(rawBaseName)_\(fileExtension)"
            case .timestamp:
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyyMMdd_HHmmss"
                formattedBaseName = "\(rawBaseName)_\(formatter.string(from: Date()))"
            case .compressed:
                formattedBaseName = "\(rawBaseName)-compressed"
            }
        }
        let baseName = formattedBaseName + nameSuffix

        lock.lock()
        defer { lock.unlock() }

        let candidate = folder.appendingPathComponent(baseName).appendingPathExtension(fileExtension)
        if AppSettings.shared.fileConflictAction == .overwrite {
            let isSameAsSource = candidate.standardizedFileURL.path.caseInsensitiveCompare(sourceURL.standardizedFileURL.path) == .orderedSame
            if isSameAsSource {
                var out = folder.appendingPathComponent("\(baseName)-converted").appendingPathExtension(fileExtension)
                var counter = 2
                while FileManager.default.fileExists(atPath: out.path) || claimedPaths.contains(out.path) {
                    out = folder.appendingPathComponent("\(baseName)-converted-\(counter)").appendingPathExtension(fileExtension)
                    counter += 1
                }
                claimedPaths.insert(out.path)
                return out
            }
            claimedPaths.insert(candidate.path)
            return candidate
        }

        var out = candidate
        var counter = 2
        while FileManager.default.fileExists(atPath: out.path) || claimedPaths.contains(out.path) {
            out = folder.appendingPathComponent("\(baseName)-\(counter)").appendingPathExtension(fileExtension)
            counter += 1
        }
        claimedPaths.insert(out.path)
        return out
    }
}
