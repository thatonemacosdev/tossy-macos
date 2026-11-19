import Foundation
import AppKit
import PDFKit

enum DocumentDataError: LocalizedError {
    case fileNotFound(URL)
    case conversionFailed(String)
    case unsupportedConversion(String, String)

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let url): return "File not found: \(url.lastPathComponent)"
        case .conversionFailed(let msg): return msg
        case .unsupportedConversion(let from, let to): return "Converting from .\(from) to .\(to) is not supported."
        }
    }
}

final class DocumentAndDataConverterService: Sendable {
    static let shared = DocumentAndDataConverterService()
    init() {}

    // MARK: - Documents (textutil & PDFKit)
    func convertDocument(sourceURL: URL, targetExtension: String, destinationFolder: URL?) async throws -> URL {
        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            throw DocumentDataError.fileNotFound(sourceURL)
        }
        let folder = destinationFolder ?? sourceURL.deletingLastPathComponent()
        let outURL = OutputNaming.uniqueOutputURL(for: sourceURL, fileExtension: targetExtension, destinationFolder: folder)
        let srcExt = sourceURL.pathExtension.lowercased()
        let dstExt = targetExtension.lowercased()

        if dstExt == "pdf" {
            let pdfData = try await MainActor.run { () throws -> Data in
                let attrString = try NSAttributedString(url: sourceURL, options: [:], documentAttributes: nil)
                let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 595, height: 842))
                textView.textStorage?.setAttributedString(attrString)
                return textView.dataWithPDF(inside: textView.bounds)
            }
            try pdfData.write(to: outURL, options: .atomic)
            return outURL
        }

        let textutilFormats = ["txt", "html", "rtf", "rtfd", "docx", "odt"]
        if textutilFormats.contains(dstExt) {
            let res = try await SubprocessRunner.run(
                executablePath: "/usr/bin/textutil",
                arguments: ["-convert", dstExt, sourceURL.path, "-output", outURL.path]
            )
            guard res.isSuccess, FileManager.default.fileExists(atPath: outURL.path) else {
                let err = res.stderrString.isEmpty ? "textutil conversion failed" : res.stderrString
                throw DocumentDataError.conversionFailed(err)
            }
            return outURL
        }

        throw DocumentDataError.unsupportedConversion(srcExt, dstExt)
    }

    // MARK: - Subtitles (SRT <-> VTT <-> TXT)
    func convertSubtitle(sourceURL: URL, targetExtension: String, destinationFolder: URL?) async throws -> URL {
        let content = try String(contentsOf: sourceURL, encoding: .utf8)
        let folder = destinationFolder ?? sourceURL.deletingLastPathComponent()
        let outURL = OutputNaming.uniqueOutputURL(for: sourceURL, fileExtension: targetExtension, destinationFolder: folder)
        let srcExt = sourceURL.pathExtension.lowercased()
        let dstExt = targetExtension.lowercased()

        let converted: String
        switch (srcExt, dstExt) {
        case ("srt", "vtt"):
            let regex = try NSRegularExpression(pattern: "(\\d{2}:\\d{2}:\\d{2}),(\\d{3})")
            let modified = regex.stringByReplacingMatches(in: content, range: NSRange(location: 0, length: content.utf16.count), withTemplate: "$1.$2")
            converted = "WEBVTT\n\n" + modified
        case ("vtt", "srt"):
            var lines = content.components(separatedBy: .newlines)
            if let first = lines.first, first.contains("WEBVTT") {
                lines.removeFirst()
            }
            let stripped = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            let regex = try NSRegularExpression(pattern: "(\\d{2}:\\d{2}:\\d{2})\\.(\\d{3})")
            converted = regex.stringByReplacingMatches(in: stripped, range: NSRange(location: 0, length: stripped.utf16.count), withTemplate: "$1,$2")
        case (_, "txt"):
            let lines = content.components(separatedBy: .newlines)
            var dialogueLines: [String] = []
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.isEmpty || trimmed.contains("-->") || trimmed.contains("WEBVTT") || Int(trimmed) != nil {
                    continue
                }
                dialogueLines.append(trimmed)
            }
            converted = dialogueLines.joined(separator: "\n")
        default:
            throw DocumentDataError.unsupportedConversion(srcExt, dstExt)
        }

        try converted.write(to: outURL, atomically: true, encoding: .utf8)
        return outURL
    }

    // MARK: - Data (JSON <-> PLIST <-> CSV)
    func convertData(sourceURL: URL, targetExtension: String, destinationFolder: URL?) async throws -> URL {
        let data = try Data(contentsOf: sourceURL)
        let folder = destinationFolder ?? sourceURL.deletingLastPathComponent()
        let outURL = OutputNaming.uniqueOutputURL(for: sourceURL, fileExtension: targetExtension, destinationFolder: folder)
        let srcExt = sourceURL.pathExtension.lowercased()
        let dstExt = targetExtension.lowercased()

        switch (srcExt, dstExt) {
        case ("json", "plist"):
            let jsonObject = try JSONSerialization.jsonObject(with: data)
            let plistData = try PropertyListSerialization.data(fromPropertyList: jsonObject, format: .xml, options: 0)
            try plistData.write(to: outURL, options: .atomic)
        case ("plist", "json"):
            let plistObject = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
            let jsonData = try JSONSerialization.data(withJSONObject: plistObject, options: [.prettyPrinted, .sortedKeys])
            try jsonData.write(to: outURL, options: .atomic)
        case ("csv", "json"):
            guard let text = String(data: data, encoding: .utf8) else {
                throw DocumentDataError.conversionFailed("Invalid CSV UTF-8 data")
            }
            let rows = text.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            guard let headerLine = rows.first else {
                throw DocumentDataError.conversionFailed("Empty CSV file")
            }
            let headers = headerLine.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            var records: [[String: String]] = []
            for row in rows.dropFirst() {
                let values = row.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                var record: [String: String] = [:]
                for (i, header) in headers.enumerated() where i < values.count {
                    record[header] = values[i]
                }
                records.append(record)
            }
            let jsonData = try JSONSerialization.data(withJSONObject: records, options: [.prettyPrinted])
            try jsonData.write(to: outURL, options: .atomic)
        case ("json", "csv"):
            let jsonObject = try JSONSerialization.jsonObject(with: data)
            guard let array = jsonObject as? [[String: Any]], let first = array.first else {
                throw DocumentDataError.conversionFailed("JSON must be an array of objects to convert to CSV")
            }
            let headers = Array(first.keys).sorted()
            var csvString = headers.joined(separator: ",") + "\n"
            for item in array {
                let row = headers.map { key -> String in
                    let val = "\(item[key] ?? "")"
                    if val.contains(",") || val.contains("\"") {
                        return "\"\(val.replacingOccurrences(of: "\"", with: "\"\""))\""
                    }
                    return val
                }
                csvString += row.joined(separator: ",") + "\n"
            }
            try csvString.write(to: outURL, atomically: true, encoding: .utf8)
        default:
            throw DocumentDataError.unsupportedConversion(srcExt, dstExt)
        }

        return outURL
    }
}
