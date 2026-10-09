import Foundation
import AppKit
import UniformTypeIdentifiers

enum FileDropResolver {
    /// Resolves an array of `NSItemProvider` drag/drop items into verified on-disk file URLs.
    /// Preserves original file paths, names, and extensions.
    static func resolveURLs(from providers: [NSItemProvider]) async -> [URL] {
        var results: [URL] = []
        for provider in providers {
            if let url = await resolveSingleURL(from: provider) {
                if !results.contains(url) {
                    results.append(url)
                }
            }
        }
        return results
    }

    private static func resolveSingleURL(from provider: NSItemProvider) async -> URL? {
        // 1. Direct URL object loading via loadObject
        if provider.canLoadObject(ofClass: URL.self) {
            if let url = await withCheckedContinuation({ (continuation: CheckedContinuation<URL?, Never>) in
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    continuation.resume(returning: url)
                }
            }) {
                if FileManager.default.fileExists(atPath: url.path) {
                    return url
                }
            }
        }

        // 2. Load item for public.file-url (UTType.fileURL)
        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            if let url = await withCheckedContinuation({ (continuation: CheckedContinuation<URL?, Never>) in
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    continuation.resume(returning: parseURLFromItem(item))
                }
            }) {
                if FileManager.default.fileExists(atPath: url.path) {
                    return url
                }
            }
        }

        // 3. Check all registered type identifiers on the provider for existing file paths
        for typeId in provider.registeredTypeIdentifiers {
            if typeId == UTType.fileURL.identifier { continue }
            if let url = await withCheckedContinuation({ (continuation: CheckedContinuation<URL?, Never>) in
                provider.loadItem(forTypeIdentifier: typeId, options: nil) { item, _ in
                    continuation.resume(returning: parseURLFromItem(item))
                }
            }) {
                if FileManager.default.fileExists(atPath: url.path) {
                    return url
                }
            }
        }

        // 4. Non-file clipboard / in-memory drag fallback (e.g. screenshot snippet or browser image data)
        return await extractRawDataFallback(from: provider)
    }

    private static func parseURLFromItem(_ item: Any?) -> URL? {
        guard let item else { return nil }

        if let url = item as? URL {
            if url.isFileURL {
                return url
            }
            if let scheme = url.scheme, scheme == "file" {
                return URL(fileURLWithPath: url.path)
            }
            return url
        }

        if let nsURL = item as? NSURL {
            return (nsURL as URL)
        }

        if let str = item as? String {
            let cleaned = str.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "\0\r\n\"'")))
            if cleaned.hasPrefix("file://"), let url = URL(string: cleaned) {
                return url
            }
            if cleaned.hasPrefix("/") {
                let direct = URL(fileURLWithPath: cleaned)
                if FileManager.default.fileExists(atPath: direct.path) {
                    return direct
                }
            }
            if let url = URL(string: cleaned), url.scheme == "file" {
                return url
            }
        }

        if let data = item as? Data {
            // Check if it is bookmark data
            var isStale = false
            if let bookmarkURL = try? URL(resolvingBookmarkData: data, options: [.withoutUI, .withoutMounting], relativeTo: nil, bookmarkDataIsStale: &isStale) {
                return bookmarkURL
            }

            // Check if it is standard URL data representation
            if let url = URL(dataRepresentation: data, relativeTo: nil) {
                return url
            }

            // Check if it contains UTF-8/UTF-16/ASCII string bytes (C-strings with null terminators)
            if let raw = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .utf16) ?? String(data: data, encoding: .ascii) {
                let cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "\0\r\n\"'")))
                let lines = cleaned.components(separatedBy: .newlines)
                for line in lines {
                    let cleanLine = line.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "\0\r\n\"'")))
                    if cleanLine.hasPrefix("file://"), let url = URL(string: cleanLine) {
                        return url
                    }
                    if cleanLine.hasPrefix("/") {
                        let direct = URL(fileURLWithPath: cleanLine)
                        if FileManager.default.fileExists(atPath: direct.path) {
                            return direct
                        }
                    }
                }
                if let url = URL(string: cleaned), url.scheme == "file" {
                    return url
                }
                if cleaned.hasPrefix("/") {
                    let direct = URL(fileURLWithPath: cleaned)
                    if FileManager.default.fileExists(atPath: direct.path) {
                        return direct
                    }
                }
            }
        }

        return nil
    }

    private static func extractRawDataFallback(from provider: NSItemProvider) async -> URL? {
        let baseName = provider.suggestedName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = (baseName?.isEmpty ?? true) ? "Pasted Media" : baseName!

        // Check if there is an in-memory image representation
        for (uti, ext) in [
            (UTType.png.identifier, "png"),
            (UTType.jpeg.identifier, "jpg"),
            (UTType.tiff.identifier, "tiff"),
            (UTType.heic.identifier, "heic"),
            (UTType.image.identifier, "png")
        ] {
            if provider.hasItemConformingToTypeIdentifier(uti) {
                if let data = await withCheckedContinuation({ (continuation: CheckedContinuation<Data?, Never>) in
                    provider.loadDataRepresentation(forTypeIdentifier: uti) { data, _ in
                        continuation.resume(returning: data)
                    }
                }) {
                    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(name)_\(UUID().uuidString.prefix(4)).\(ext)")
                    if (try? data.write(to: tempURL)) != nil {
                        return tempURL
                    }
                }
            }
        }

        return nil
    }
}
