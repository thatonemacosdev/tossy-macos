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
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
            process.arguments = ["-x", "-k", archiveURL.path, safeFolder.path]
            let errPipe = Pipe()
            process.standardError = errPipe
            
            try process.run()
            process.waitUntilExit()
            
            if process.terminationStatus != 0 {
                // Try fallback with /usr/bin/unzip if encrypted with password
                let unzipProcess = Process()
                unzipProcess.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
                var unzipArgs = ["-q", "-o"]
                if let password, !password.isEmpty {
                    unzipArgs += ["-P", password]
                }
                unzipArgs += [archiveURL.path, "-d", safeFolder.path]
                unzipProcess.arguments = unzipArgs
                let unzipErr = Pipe()
                unzipProcess.standardError = unzipErr
                try unzipProcess.run()
                unzipProcess.waitUntilExit()
                
                guard unzipProcess.terminationStatus == 0 else {
                    let errData = unzipErr.fileHandleForReading.readDataToEndOfFile()
                    let errStr = String(data: errData, encoding: .utf8) ?? ""
                    throw ArchiveError.extractionFailed("Unzip failed (code \(unzipProcess.terminationStatus)): \(errStr.suffix(200))")
                }
            }
        } else if ["tar", "gz", "tgz", "bz2", "tbz2", "xz", "txz"].contains(ext) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
            process.arguments = ["-xf", archiveURL.path, "-C", safeFolder.path]
            let errPipe = Pipe()
            process.standardError = errPipe
            
            try process.run()
            process.waitUntilExit()
            
            guard process.terminationStatus == 0 else {
                let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                let errStr = String(data: errData, encoding: .utf8) ?? ""
                throw ArchiveError.extractionFailed("Tar extract failed: \(errStr.suffix(200))")
            }
        } else {
            // General 7z / fallback
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
            process.arguments = ["-xf", archiveURL.path, "-C", safeFolder.path]
            let errPipe = Pipe()
            process.standardError = errPipe
            try process.run()
            process.waitUntilExit()
            
            guard process.terminationStatus == 0 else {
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
            // Password protected zip
            let parentFolder = sourceURLs[0].deletingLastPathComponent()
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
            process.currentDirectoryURL = parentFolder
            
            var args = ["-q", "-r", "-P", password, safeDestination.path]
            for url in sourceURLs {
                args.append(url.lastPathComponent)
            }
            process.arguments = args
            let errPipe = Pipe()
            process.standardError = errPipe
            
            try process.run()
            process.waitUntilExit()
            
            guard process.terminationStatus == 0, FileManager.default.fileExists(atPath: safeDestination.path) else {
                let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                let errStr = String(data: errData, encoding: .utf8) ?? ""
                throw ArchiveError.compressionFailed("Encrypted zip creation failed: \(errStr.suffix(200))")
            }
        } else if format.lowercased() == "zip" {
            // Use ditto for clean macOS zip creation with resource preservation
            if sourceURLs.count == 1 {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
                process.arguments = ["-c", "-k", "--keepParent", sourceURLs[0].path, safeDestination.path]
                try process.run()
                process.waitUntilExit()
                guard process.terminationStatus == 0 else {
                    throw ArchiveError.compressionFailed("Ditto zip failed")
                }
            } else {
                let parentFolder = sourceURLs[0].deletingLastPathComponent()
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
                process.currentDirectoryURL = parentFolder
                var args = ["-q", "-r", safeDestination.path]
                for url in sourceURLs {
                    args.append(url.lastPathComponent)
                }
                process.arguments = args
                try process.run()
                process.waitUntilExit()
                guard process.terminationStatus == 0 else {
                    throw ArchiveError.compressionFailed("Zip creation failed")
                }
            }
        } else if ["tar.gz", "tgz"].contains(format.lowercased()) {
            let parentFolder = sourceURLs[0].deletingLastPathComponent()
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
            process.currentDirectoryURL = parentFolder
            var args = ["-czf", safeDestination.path]
            for url in sourceURLs {
                args.append(url.lastPathComponent)
            }
            process.arguments = args
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else {
                throw ArchiveError.compressionFailed("Tar.gz creation failed")
            }
        } else {
            // Standard tar fallback
            let parentFolder = sourceURLs[0].deletingLastPathComponent()
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
            process.currentDirectoryURL = parentFolder
            var args = ["-cf", safeDestination.path]
            for url in sourceURLs {
                args.append(url.lastPathComponent)
            }
            process.arguments = args
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else {
                throw ArchiveError.compressionFailed("Archive creation failed")
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
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/split")
        let baseName = archiveURL.lastPathComponent
        let prefix = safeFolder.appendingPathComponent("\(baseName).part_").path
        
        process.arguments = ["-b", "\(chunkSizeBytes)", archiveURL.path, prefix]
        try process.run()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            throw ArchiveError.compressionFailed("Volume splitting failed")
        }
        
        let parts = (try? FileManager.default.contentsOfDirectory(at: safeFolder, includingPropertiesForKeys: nil))?
            .filter { $0.lastPathComponent.hasPrefix("\(baseName).part_") }
            .sorted { $0.lastPathComponent < $1.lastPathComponent } ?? []
        
        return parts
    }
}
