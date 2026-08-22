import Foundation

enum OutputNaming {
    // Image, media, and document jobs can run concurrently, so two jobs
    // picking a name at the same instant could both see the same path as free via fileExists
    // and collide. This lock plus an in-memory registry of already-handed-out paths closes
    // that window without touching the filesystem.
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
    /// Zero-overwrite guarantee: appends (1), (2), etc. if the file or path already exists.
    static func uniqueOutputURL(
        for sourceURL: URL,
        fileExtension: String,
        destinationFolder: URL?,
        nameSuffix: String = "",
        baseNameOverride: String? = nil
    ) -> URL {
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
        if !FileManager.default.fileExists(atPath: candidate.path) && !claimedPaths.contains(candidate.path) {
            claimedPaths.insert(candidate.path)
            return candidate
        }

        var counter = 1
        var out = folder.appendingPathComponent("\(baseName) (\(counter))").appendingPathExtension(fileExtension)
        while FileManager.default.fileExists(atPath: out.path) || claimedPaths.contains(out.path) {
            counter += 1
            out = folder.appendingPathComponent("\(baseName) (\(counter))").appendingPathExtension(fileExtension)
        }
        claimedPaths.insert(out.path)
        return out
    }

    /// Ensures any arbitrary target file URL is non-colliding by appending (1), (2), etc. if needed.
    static func uniqueDestinationURL(desiredURL: URL) -> URL {
        lock.lock()
        defer { lock.unlock() }

        if !FileManager.default.fileExists(atPath: desiredURL.path) && !claimedPaths.contains(desiredURL.path) {
            claimedPaths.insert(desiredURL.path)
            return desiredURL
        }

        let folder = desiredURL.deletingLastPathComponent()
        let baseName = desiredURL.deletingPathExtension().lastPathComponent
        let ext = desiredURL.pathExtension

        var counter = 1
        var out: URL
        if ext.isEmpty {
            out = folder.appendingPathComponent("\(baseName) (\(counter))")
        } else {
            out = folder.appendingPathComponent("\(baseName) (\(counter))").appendingPathExtension(ext)
        }

        while FileManager.default.fileExists(atPath: out.path) || claimedPaths.contains(out.path) {
            counter += 1
            if ext.isEmpty {
                out = folder.appendingPathComponent("\(baseName) (\(counter))")
            } else {
                out = folder.appendingPathComponent("\(baseName) (\(counter))").appendingPathExtension(ext)
            }
        }

        claimedPaths.insert(out.path)
        return out
    }

    /// Ensures any arbitrary target folder URL is non-colliding by appending (1), (2), etc. if needed.
    static func uniqueFolderURL(desiredFolderURL: URL) -> URL {
        lock.lock()
        defer { lock.unlock() }

        if !FileManager.default.fileExists(atPath: desiredFolderURL.path) && !claimedPaths.contains(desiredFolderURL.path) {
            claimedPaths.insert(desiredFolderURL.path)
            return desiredFolderURL
        }

        let parent = desiredFolderURL.deletingLastPathComponent()
        let folderName = desiredFolderURL.lastPathComponent

        var counter = 1
        var out = parent.appendingPathComponent("\(folderName) (\(counter))")
        while FileManager.default.fileExists(atPath: out.path) || claimedPaths.contains(out.path) {
            counter += 1
            out = parent.appendingPathComponent("\(folderName) (\(counter))")
        }

        claimedPaths.insert(out.path)
        return out
    }
}
