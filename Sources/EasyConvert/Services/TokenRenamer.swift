import Foundation

enum CaseTransform: String, CaseIterable, Identifiable, Sendable {
    case original = "Original Case"
    case lower = "lowercase"
    case upper = "UPPERCASE"
    case title = "Title Case"
    case camelCase = "camelCase"
    case snakeCase = "snake_case"
    case kebabCase = "kebab-case"
    
    var id: String { rawValue }
    
    func apply(to string: String) -> String {
        switch self {
        case .original:
            return string
        case .lower:
            return string.lowercased()
        case .upper:
            return string.uppercased()
        case .title:
            return string.capitalized
        case .camelCase:
            let words = string.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
            guard let first = words.first?.lowercased() else { return string }
            let rest = words.dropFirst().map { $0.capitalized }.joined()
            return first + rest
        case .snakeCase:
            let words = string.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
            return words.map { $0.lowercased() }.joined(separator: "_")
        case .kebabCase:
            let words = string.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
            return words.map { $0.lowercased() }.joined(separator: "-")
        }
    }
}

struct RenamingPreview: Identifiable, Sendable {
    let id = UUID()
    let originalURL: URL
    let originalName: String
    let newName: String
    let targetURL: URL
}

final class TokenRenamer: Sendable {
    static let shared = TokenRenamer()
    
    init() {}
    
    /// Evaluates the renamed filename for a single file according to template and rules.
    func formatName(
        fileURL: URL,
        pattern: String = "{name}",
        caseTransform: CaseTransform = .original,
        findRegex: String? = nil,
        replaceRegex: String? = nil,
        index: Int = 1
    ) -> String {
        let baseName = fileURL.deletingPathExtension().lastPathComponent
        let ext = fileURL.pathExtension
        
        let now = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateStr = dateFormatter.string(from: now)
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH-mm-ss"
        let timeStr = timeFormatter.string(from: now)
        
        let yearFormatter = DateFormatter()
        yearFormatter.dateFormat = "yyyy"
        let yearStr = yearFormatter.string(from: now)
        
        var result = pattern
        result = result.replacingOccurrences(of: "{name}", with: baseName)
        result = result.replacingOccurrences(of: "{ext}", with: ext)
        result = result.replacingOccurrences(of: "{date}", with: dateStr)
        result = result.replacingOccurrences(of: "{year}", with: yearStr)
        result = result.replacingOccurrences(of: "{time}", with: timeStr)
        result = result.replacingOccurrences(of: "{index}", with: "\(index)")
        
        // Zero padded counter token: {counter:3} -> "001"
        if let counterRegex = try? NSRegularExpression(pattern: #"\{counter:(\d+)\}"#) {
            let nsResult = result as NSString
            let matches = counterRegex.matches(in: result, range: NSRange(location: 0, length: nsResult.length))
            for match in matches.reversed() {
                if let padRange = Range(match.range(at: 1), in: result),
                   let padDigits = Int(result[padRange]) {
                    let formattedIndex = String(format: "%0\(padDigits)d", index)
                    if let fullRange = Range(match.range(at: 0), in: result) {
                        result.replaceSubrange(fullRange, with: formattedIndex)
                    }
                }
            }
        }
        
        // Regex find & replace
        if let findRegex, !findRegex.isEmpty, let replaceRegex {
            if let reg = try? NSRegularExpression(pattern: findRegex) {
                let range = NSRange(location: 0, length: (result as NSString).length)
                result = reg.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: replaceRegex)
            }
        }
        
        // Case transform
        result = caseTransform.apply(to: result)
        
        // Append extension if not explicitly included in pattern
        if !pattern.contains("{ext}") && !ext.isEmpty {
            result = "\(result).\(ext)"
        }
        
        return result
    }
    
    /// Generates previews for batch renaming before committing changes to disk.
    func generatePreviews(
        urls: [URL],
        pattern: String = "{name}",
        caseTransform: CaseTransform = .original,
        findRegex: String? = nil,
        replaceRegex: String? = nil,
        startIndex: Int = 1
    ) -> [RenamingPreview] {
        var previews: [RenamingPreview] = []
        for (offset, url) in urls.enumerated() {
            let newName = formatName(
                fileURL: url,
                pattern: pattern,
                caseTransform: caseTransform,
                findRegex: findRegex,
                replaceRegex: replaceRegex,
                index: startIndex + offset
            )
            let targetURL = url.deletingLastPathComponent().appendingPathComponent(newName)
            previews.append(RenamingPreview(
                originalURL: url,
                originalName: url.lastPathComponent,
                newName: newName,
                targetURL: targetURL
            ))
        }
        return previews
    }
    
    /// Commits the batch rename operation safely on the filesystem.
    func applyBatchRename(
        urls: [URL],
        pattern: String = "{name}",
        caseTransform: CaseTransform = .original,
        findRegex: String? = nil,
        replaceRegex: String? = nil,
        startIndex: Int = 1
    ) throws -> [URL] {
        let previews = generatePreviews(
            urls: urls,
            pattern: pattern,
            caseTransform: caseTransform,
            findRegex: findRegex,
            replaceRegex: replaceRegex,
            startIndex: startIndex
        )
        
        var renamedURLs: [URL] = []
        for item in previews {
            if item.originalURL != item.targetURL {
                try FileManager.default.moveItem(at: item.originalURL, to: item.targetURL)
            }
            renamedURLs.append(item.targetURL)
        }
        return renamedURLs
    }
}
