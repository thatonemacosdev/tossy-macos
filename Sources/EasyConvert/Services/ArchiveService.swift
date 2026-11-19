import Foundation

enum ArchiveError: LocalizedError, Sendable {
    case fileNotFound(URL)
    case unsupportedArchiveFormat(String)
    case extractionFailed(String)
    case compressionFailed(String)
    case passwordRequired
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound(let url):
            return "Archive file not found at: \(url.path)"
        case .unsupportedArchiveFormat(let ext):
            return "Unsupported archive extension: .\(ext)"
        case .extractionFailed(let details):
            return "Archive extraction failed: \(details)"
        case .compressionFailed(let details):
            return "Archive compression failed: \(details)"
        case .passwordRequired:
            return "This archive is password-protected. Please provide a password."
        }
    }
}

final class ArchiveService: Sendable {
    static let shared = ArchiveService()
    
    init() {}
    
    static let supportedArchiveExtensions = Set([
        "zip", "tar", "gz", "tgz", "bz2", "tbz2", "xz", "txz", "7z", "rar", "iso"
    ])
    
    /// Unpacks any supported archive (ZIP, TAR, GZ, BZ2, XZ, 7Z, ISO) into a destination directory.
    func extractArchive(
        archiveURL: URL,
        destinationFolder: URL,
        password: String? = nil,
        onProgress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> [URL] {
        guard FileManager.default.fileExists(atPath: archiveURL.path) else {
            throw ArchiveError.fileNotFound(archiveURL)
        }
        
        let safeFolder = OutputNaming.uniqueFolderURL(desiredFolderURL: destinationFolder)
        try? FileManager.default.createDirectory(at: safeFolder, withIntermediateDirectories: true)
        let ext = archiveURL.pathExtension.lowercased()
        
        if ext == "zip" {
            // Use ditto for clean macOS metadata and resource fork preservation
            let dittoResult = try await SubprocessRunner.run(
                executablePath: "/usr/bin/ditto",
                arguments: ["-x", "-k", archiveURL.path, safeFolder.path]
            )
            
            if !dittoResult.isSuccess {
                // Try fallback with /usr/bin/unzip if encrypted with password
                var unzipArgs = ["-q", "-o"]
                if let password, !password.isEmpty {
                    unzipArgs += ["-P", password]
                }
                unzipArgs += [archiveURL.path, "-d", safeFolder.path]
                let unzipResult = try await SubprocessRunner.run(executablePath: "/usr/bin/unzip", arguments: unzipArgs)
                guard unzipResult.isSuccess else {
                    throw ArchiveError.extractionFailed("Unzip failed (code \(unzipResult.exitCode)): \(unzipResult.stderrString.suffix(200))")
                }
            }
        } else if ["tar", "gz", "tgz", "bz2", "tbz2", "xz", "txz", "zst"].contains(ext) {
            let tarResult = try await SubprocessRunner.run(
                executablePath: "/usr/bin/tar",
                arguments: ["-xf", archiveURL.path, "-C", safeFolder.path]
            )
            guard tarResult.isSuccess else {
                throw ArchiveError.extractionFailed("Tar extract failed: \(tarResult.stderrString.suffix(200))")
            }
        } else {
            let tarResult = try await SubprocessRunner.run(
                executablePath: "/usr/bin/tar",
                arguments: ["-xf", archiveURL.path, "-C", safeFolder.path]
            )
            guard tarResult.isSuccess else {
                throw ArchiveError.unsupportedArchiveFormat(ext)
            }
        }
        
        onProgress?(1.0)
        
        let extractedItems = (try? FileManager.default.contentsOfDirectory(at: safeFolder, includingPropertiesForKeys: nil)) ?? []
        return extractedItems
    }
    
    /// Creates a compressed ZIP or TAR archive, with optional AES password encryption.
    func createArchive(
        sourceURLs: [URL],
        format: String = "zip",
        password: String? = nil,
        destinationURL: URL,
        onProgress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> URL {
        guard !sourceURLs.isEmpty else {
            throw ArchiveError.compressionFailed("No source files specified")
        }
        
        let destFolder = destinationURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: destFolder, withIntermediateDirectories: true)
        let safeDestination = OutputNaming.uniqueDestinationURL(desiredURL: destinationURL)
        
        if let password, !password.isEmpty {
            let parentFolder = sourceURLs[0].deletingLastPathComponent()
            var args = ["-q", "-r", "-P", password, safeDestination.path]
            for url in sourceURLs {
                args.append(url.lastPathComponent)
            }
            let result = try await SubprocessRunner.run(
                executablePath: "/usr/bin/zip",
                arguments: args,
                currentDirectoryURL: parentFolder
            )
            guard result.isSuccess, FileManager.default.fileExists(atPath: safeDestination.path) else {
                throw ArchiveError.compressionFailed("Encrypted zip creation failed: \(result.stderrString.suffix(200))")
            }
        } else if format.lowercased() == "zip" {
            if sourceURLs.count == 1 {
                let result = try await SubprocessRunner.run(
                    executablePath: "/usr/bin/ditto",
                    arguments: ["-c", "-k", "--keepParent", sourceURLs[0].path, safeDestination.path]
                )
                guard result.isSuccess else {
                    throw ArchiveError.compressionFailed("Ditto zip failed")
                }
            } else {
                let parentFolder = sourceURLs[0].deletingLastPathComponent()
                var args = ["-q", "-r", safeDestination.path]
                for url in sourceURLs {
                    args.append(url.lastPathComponent)
                }
                let result = try await SubprocessRunner.run(
                    executablePath: "/usr/bin/zip",
                    arguments: args,
                    currentDirectoryURL: parentFolder
                )
                guard result.isSuccess else {
                    throw ArchiveError.compressionFailed("Zip creation failed")
                }
            }
        } else {
            let parentFolder = sourceURLs[0].deletingLastPathComponent()
            let tarFlag: String
            let lowerFormat = format.lowercased()
            if ["tar.gz", "tgz"].contains(lowerFormat) {
                tarFlag = "-czf"
            } else if ["tar.bz2", "tbz2", "bz2"].contains(lowerFormat) {
                tarFlag = "-cjf"
            } else if ["tar.xz", "txz", "xz"].contains(lowerFormat) {
                tarFlag = "-cJf"
            } else {
                tarFlag = "-cf"
            }

            var args = [tarFlag, safeDestination.path]
            for url in sourceURLs {
                args.append(url.lastPathComponent)
            }
            let result = try await SubprocessRunner.run(
                executablePath: "/usr/bin/tar",
                arguments: args,
                currentDirectoryURL: parentFolder
            )
            guard result.isSuccess else {
                throw ArchiveError.compressionFailed("Archive creation failed: \(result.stderrString.suffix(200))")
            }
        }
        
        onProgress?(1.0)
        return safeDestination
    }
    
    /// Splits a large archive file into multi-part volume chunks (e.g. 500 MB).
    func splitIntoVolumes(
        archiveURL: URL,
        chunkSizeBytes: Int64,
        destinationFolder: URL
    ) async throws -> [URL] {
        guard FileManager.default.fileExists(atPath: archiveURL.path) else {
            throw ArchiveError.fileNotFound(archiveURL)
        }
        guard chunkSizeBytes > 1024 * 1024 else {
            throw ArchiveError.compressionFailed("Chunk size must be at least 1MB")
        }
        
        let safeFolder = OutputNaming.uniqueFolderURL(desiredFolderURL: destinationFolder)
        try? FileManager.default.createDirectory(at: safeFolder, withIntermediateDirectories: true)
        
        let baseName = archiveURL.lastPathComponent
        let prefix = safeFolder.appendingPathComponent("\(baseName).part_").path
        
        let result = try await SubprocessRunner.run(
            executablePath: "/usr/bin/split",
            arguments: ["-b", "\(chunkSizeBytes)", archiveURL.path, prefix]
        )
        guard result.isSuccess else {
            throw ArchiveError.compressionFailed("Volume splitting failed")
        }
        
        let parts = (try? FileManager.default.contentsOfDirectory(at: safeFolder, includingPropertiesForKeys: nil))?
            .filter { $0.lastPathComponent.hasPrefix("\(baseName).part_") }
            .sorted { $0.lastPathComponent < $1.lastPathComponent } ?? []
        
        return parts
    }
}
