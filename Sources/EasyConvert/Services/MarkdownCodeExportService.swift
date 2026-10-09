import Foundation
import AppKit
import CoreGraphics
import PDFKit

enum CodeCardTheme: String, CaseIterable, Identifiable, Sendable {
    case darkTitanium = "Dark Modern (VS Code)"
    case lightMinimal = "Light Minimal"
    case matrixGreen = "Matrix Terminal"
    
    var id: String { rawValue }
    
    var backgroundColor: NSColor {
        switch self {
        case .darkTitanium: return NSColor(red: 0.11, green: 0.11, blue: 0.13, alpha: 1.0)
        case .lightMinimal: return NSColor(white: 0.98, alpha: 1.0)
        case .matrixGreen: return NSColor(red: 0.02, green: 0.05, blue: 0.02, alpha: 1.0)
        }
    }
    
    var defaultTextColor: NSColor {
        switch self {
        case .darkTitanium: return NSColor(red: 0.86, green: 0.86, blue: 0.86, alpha: 1.0)
        case .lightMinimal: return NSColor(white: 0.15, alpha: 1.0)
        case .matrixGreen: return NSColor(red: 0.2, green: 0.9, blue: 0.3, alpha: 1.0)
        }
    }
    
    var lineNumberColor: NSColor {
        switch self {
        case .darkTitanium: return NSColor(white: 0.35, alpha: 1.0)
        case .lightMinimal: return NSColor(white: 0.65, alpha: 1.0)
        case .matrixGreen: return NSColor(red: 0.1, green: 0.45, blue: 0.15, alpha: 1.0)
        }
    }
}

// MARK: - Language Syntax Color Tokens

struct CodeSyntaxTheme {
    let keywordPink: NSColor
    let keywordBlue: NSColor
    let stringOrange: NSColor
    let commentGreen: NSColor
    let numberGreen: NSColor
    let typeMint: NSColor
    let functionYellow: NSColor
    let variableCyan: NSColor
    let decoratorGold: NSColor
    let defaultText: NSColor
    
    static let vsCodeDark = CodeSyntaxTheme(
        keywordPink: NSColor(red: 0.77, green: 0.52, blue: 0.75, alpha: 1.0),   // #C586C0
        keywordBlue: NSColor(red: 0.34, green: 0.61, blue: 0.84, alpha: 1.0),   // #569CD6
        stringOrange: NSColor(red: 0.81, green: 0.57, blue: 0.47, alpha: 1.0),  // #CE9178
        commentGreen: NSColor(red: 0.42, green: 0.60, blue: 0.33, alpha: 1.0),  // #6A9955
        numberGreen: NSColor(red: 0.71, green: 0.81, blue: 0.66, alpha: 1.0),   // #B5CEA8
        typeMint: NSColor(red: 0.31, green: 0.79, blue: 0.69, alpha: 1.0),      // #4EC9B0
        functionYellow: NSColor(red: 0.86, green: 0.86, blue: 0.67, alpha: 1.0),// #DCDCAA
        variableCyan: NSColor(red: 0.61, green: 0.86, blue: 0.99, alpha: 1.0),  // #9CDCFE
        decoratorGold: NSColor(red: 0.84, green: 0.73, blue: 0.49, alpha: 1.0), // #D7BA7D
        defaultText: NSColor(red: 0.86, green: 0.86, blue: 0.86, alpha: 1.0)    // #D4D4D4
    )
    
    static let vsCodeLight = CodeSyntaxTheme(
        keywordPink: NSColor(red: 0.68, green: 0.0, blue: 0.52, alpha: 1.0),
        keywordBlue: NSColor(red: 0.0, green: 0.0, blue: 0.80, alpha: 1.0),
        stringOrange: NSColor(red: 0.64, green: 0.08, blue: 0.08, alpha: 1.0),
        commentGreen: NSColor(red: 0.0, green: 0.50, blue: 0.0, alpha: 1.0),
        numberGreen: NSColor(red: 0.05, green: 0.50, blue: 0.30, alpha: 1.0),
        typeMint: NSColor(red: 0.15, green: 0.50, blue: 0.60, alpha: 1.0),
        functionYellow: NSColor(red: 0.45, green: 0.35, blue: 0.0, alpha: 1.0),
        variableCyan: NSColor(red: 0.0, green: 0.10, blue: 0.40, alpha: 1.0),
        decoratorGold: NSColor(red: 0.55, green: 0.40, blue: 0.0, alpha: 1.0),
        defaultText: NSColor(white: 0.15, alpha: 1.0)
    )
    
    static let matrixGreenTheme = CodeSyntaxTheme(
        keywordPink: NSColor(red: 0.4, green: 1.0, blue: 0.5, alpha: 1.0),
        keywordBlue: NSColor(red: 0.3, green: 0.9, blue: 0.4, alpha: 1.0),
        stringOrange: NSColor(red: 0.8, green: 1.0, blue: 0.3, alpha: 1.0),
        commentGreen: NSColor(red: 0.15, green: 0.50, blue: 0.20, alpha: 1.0),
        numberGreen: NSColor(red: 0.6, green: 1.0, blue: 0.6, alpha: 1.0),
        typeMint: NSColor(red: 0.4, green: 1.0, blue: 0.7, alpha: 1.0),
        functionYellow: NSColor(red: 0.7, green: 1.0, blue: 0.2, alpha: 1.0),
        variableCyan: NSColor(red: 0.3, green: 0.95, blue: 0.8, alpha: 1.0),
        decoratorGold: NSColor(red: 0.9, green: 1.0, blue: 0.4, alpha: 1.0),
        defaultText: NSColor(red: 0.2, green: 0.9, blue: 0.3, alpha: 1.0)
    )
}

final class MarkdownCodeExportService: Sendable {
    static let shared = MarkdownCodeExportService()
    
    init() {}
    
    /// Renders source code snippet into a high-res PNG image card with macOS window chrome and VS Code syntax coloring.
    func renderCodeCard(
        sourceCode: String,
        language: String = "Swift",
        title: String? = nil,
        theme: CodeCardTheme = .darkTitanium,
        destination: URL
    ) async throws -> URL {
        let destinationFolder = destination.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: destinationFolder, withIntermediateDirectories: true)
        
        let lines = sourceCode.components(separatedBy: .newlines)
        let maxLines = max(1, lines.count)
        
        let font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        let headerFont = NSFont.systemFont(ofSize: 12, weight: .semibold)
        let lineNumFont = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        
        let lineHeight: CGFloat = 22.0
        let headerHeight: CGFloat = 44.0
        let padding: CGFloat = 24.0
        let lineNumWidth: CGFloat = 46.0
        
        var maxLineWidth: CGFloat = 420.0
        for line in lines {
            let width = (line as NSString).size(withAttributes: [.font: font]).width
            if width > maxLineWidth { maxLineWidth = width }
        }
        
        let totalWidth = max(580.0, maxLineWidth + lineNumWidth + (padding * 2) + 24.0)
        let totalHeight = headerHeight + (CGFloat(maxLines) * lineHeight) + (padding * 2)
        
        let scale: CGFloat = 2.0
        let pixelWidth = Int(totalWidth * scale)
        let pixelHeight = Int(totalHeight * scale)
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        
        guard let context = CGContext(
            data: nil,
            width: pixelWidth,
            height: pixelHeight,
            bitsPerComponent: 8,
            bytesPerRow: pixelWidth * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            throw PDFServiceError.writeFailed(destination)
        }
        
        NSGraphicsContext.saveGraphicsState()
        let nsContext = NSGraphicsContext(cgContext: context, flipped: false)
        NSGraphicsContext.current = nsContext
        
        context.scaleBy(x: scale, y: scale)
        
        // Background card
        let cardRect = CGRect(x: 0, y: 0, width: totalWidth, height: totalHeight)
        let cardPath = NSBezierPath(roundedRect: cardRect, xRadius: 12, yRadius: 12)
        theme.backgroundColor.setFill()
        cardPath.fill()
        
        // Subtle border
        let borderPath = NSBezierPath(roundedRect: cardRect.insetBy(dx: 0.5, dy: 0.5), xRadius: 12, yRadius: 12)
        NSColor(white: 0.25, alpha: 0.4).setStroke()
        borderPath.lineWidth = 1.0
        borderPath.stroke()
        
        // Window Control Buttons (macOS traffic lights)
        let dotY = totalHeight - 26.0
        let redDot = NSBezierPath(ovalIn: CGRect(x: padding, y: dotY, width: 12, height: 12))
        NSColor(red: 1.0, green: 0.36, blue: 0.33, alpha: 1.0).setFill()
        redDot.fill()
        
        let yellowDot = NSBezierPath(ovalIn: CGRect(x: padding + 19, y: dotY, width: 12, height: 12))
        NSColor(red: 1.0, green: 0.74, blue: 0.18, alpha: 1.0).setFill()
        yellowDot.fill()
        
        let greenDot = NSBezierPath(ovalIn: CGRect(x: padding + 38, y: dotY, width: 12, height: 12))
        NSColor(red: 0.18, green: 0.80, blue: 0.33, alpha: 1.0).setFill()
        greenDot.fill()
        
        // Title in header
        let displayTitle = title ?? "\(language.lowercased()) file"
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: headerFont,
            .foregroundColor: theme.defaultTextColor.withAlphaComponent(0.65)
        ]
        let titleSize = (displayTitle as NSString).size(withAttributes: titleAttrs)
        let titleRect = CGRect(
            x: (totalWidth - titleSize.width) / 2.0,
            y: dotY - 1.0,
            width: titleSize.width,
            height: titleSize.height
        )
        (displayTitle as NSString).draw(in: titleRect, withAttributes: titleAttrs)
        
        // Select syntax palette
        let syntaxTheme: CodeSyntaxTheme
        switch theme {
        case .darkTitanium: syntaxTheme = .vsCodeDark
        case .lightMinimal: syntaxTheme = .vsCodeLight
        case .matrixGreen: syntaxTheme = .matrixGreenTheme
        }
        
        // Render lines with syntax highlighting and line numbers
        var currentY = totalHeight - headerHeight - padding
        
        for (index, line) in lines.enumerated() {
            let lineNumStr = String(format: "%d", index + 1)
            let lineNumAttrs: [NSAttributedString.Key: Any] = [
                .font: lineNumFont,
                .foregroundColor: theme.lineNumberColor
            ]
            let lineNumRect = CGRect(x: padding, y: currentY - 14.0, width: lineNumWidth - 10.0, height: lineHeight)
            (lineNumStr as NSString).draw(in: lineNumRect, withAttributes: lineNumAttrs)
            
            // Highlight and draw line tokens
            let attributedLine = highlightLine(line, language: language, syntaxTheme: syntaxTheme, font: font)
            let codePoint = CGPoint(x: padding + lineNumWidth, y: currentY - 14.0)
            attributedLine.draw(at: codePoint)
            
            currentY -= lineHeight
        }
        
        NSGraphicsContext.restoreGraphicsState()
        
        guard let cgImage = context.makeImage() else {
            throw PDFServiceError.writeFailed(destination)
        }
        
        let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: totalWidth, height: totalHeight))
        guard let tiffData = nsImage.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            throw PDFServiceError.writeFailed(destination)
        }
        
        try pngData.write(to: destination, options: .atomic)
        return destination
    }
    
    // MARK: - Language-Specific Syntax Tokenizer
    
    private func highlightLine(
        _ line: String,
        language: String,
        syntaxTheme: CodeSyntaxTheme,
        font: NSFont
    ) -> NSAttributedString {
        let result = NSMutableAttributedString(
            string: line,
            attributes: [
                .font: font,
                .foregroundColor: syntaxTheme.defaultText
            ]
        )
        
        // 1. Comments
        if let commentRange = getCommentRange(in: line, language: language) {
            let commentFont = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
            result.addAttributes([
                .foregroundColor: syntaxTheme.commentGreen,
                .font: commentFont
            ], range: commentRange)
            return result // Comment lines don't highlight further
        }
        
        // 2. String Literals ("...", '...', `...`)
        let stringRanges = getStringLiteralRanges(in: line)
        for sRange in stringRanges {
            result.addAttribute(.foregroundColor, value: syntaxTheme.stringOrange, range: sRange)
        }
        
        // 3. Numbers
        let numberRanges = getRegexRanges(pattern: "\\b(0x[0-9a-fA-F]+|\\d+(\\.\\d+)?f?)\\b", in: line)
        for nRange in numberRanges where !isCovered(range: nRange, by: stringRanges) {
            result.addAttribute(.foregroundColor, value: syntaxTheme.numberGreen, range: nRange)
        }
        
        // 4. Decorators / Attributes (@State, @MainActor, @property, #include, etc.)
        let decoratorRanges = getRegexRanges(pattern: "(@[a-zA-Z0-9_]+|#[a-zA-Z0-9_]+)", in: line)
        for dRange in decoratorRanges where !isCovered(range: dRange, by: stringRanges) {
            result.addAttribute(.foregroundColor, value: syntaxTheme.decoratorGold, range: dRange)
        }
        
        // 5. Types / Classes / Structs (PascalCase)
        let typeRanges = getRegexRanges(pattern: "\\b[A-Z][a-zA-Z0-9_]*\\b", in: line)
        for tRange in typeRanges where !isCovered(range: tRange, by: stringRanges) {
            result.addAttribute(.foregroundColor, value: syntaxTheme.typeMint, range: tRange)
        }
        
        // 6. Function Calls / Definitions
        let funcRanges = getRegexRanges(pattern: "\\b[a-zA-Z_][a-zA-Z0-9_]*(?=\\s*\\()", in: line)
        for fRange in funcRanges where !isCovered(range: fRange, by: stringRanges) {
            result.addAttribute(.foregroundColor, value: syntaxTheme.functionYellow, range: fRange)
        }
        
        // 7. Language Keywords
        let keywords = keywordsForLanguage(language)
        for kw in keywords {
            let kwRanges = getRegexRanges(pattern: "\\b\(kw)\\b", in: line)
            for kRange in kwRanges where !isCovered(range: kRange, by: stringRanges) {
                let kwColor = isControlFlowKeyword(kw) ? syntaxTheme.keywordPink : syntaxTheme.keywordBlue
                result.addAttribute(.foregroundColor, value: kwColor, range: kRange)
            }
        }
        
        return result
    }
    
    private func getCommentRange(in line: String, language: String) -> NSRange? {
        let nsLine = line as NSString
        let commentPrefixes: [String]
        switch language.lowercased() {
        case "python", "py", "shell", "sh", "bash", "zsh", "ruby", "rb", "yaml", "yml":
            commentPrefixes = ["#"]
        case "sql":
            commentPrefixes = ["--", "//"]
        case "html", "xml":
            commentPrefixes = ["<!--"]
        default:
            commentPrefixes = ["//", "/*"]
        }
        
        for prefix in commentPrefixes {
            let range = nsLine.range(of: prefix)
            if range.location != NSNotFound {
                return NSRange(location: range.location, length: nsLine.length - range.location)
            }
        }
        return nil
    }
    
    private func getStringLiteralRanges(in line: String) -> [NSRange] {
        return getRegexRanges(pattern: "(\"(\\\\.|[^\"])*\"|'(\\\\.|[^'])*'|`(\\\\.|[^`])*`)", in: line)
    }
    
    private func getRegexRanges(pattern: String, in text: String) -> [NSRange] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return [] }
        let nsText = text as NSString
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))
        return matches.map { $0.range }
    }
    
    private func isCovered(range: NSRange, by parentRanges: [NSRange]) -> Bool {
        for parent in parentRanges {
            if range.location >= parent.location && (range.location + range.length) <= (parent.location + parent.length) {
                return true
            }
        }
        return false
    }
    
    private func isControlFlowKeyword(_ kw: String) -> Bool {
        let controlFlow = Set([
            "if", "else", "elif", "guard", "return", "switch", "case", "default", "for", "in", "while",
            "do", "repeat", "break", "continue", "throw", "throws", "try", "catch", "finally", "match", "yield"
        ])
        return controlFlow.contains(kw)
    }
    
    private func keywordsForLanguage(_ language: String) -> Set<String> {
        switch language.lowercased() {
        case "swift":
            return [
                "func", "var", "let", "struct", "class", "enum", "protocol", "extension", "import", "guard",
                "if", "else", "return", "switch", "case", "default", "for", "in", "while", "repeat", "do",
                "catch", "try", "throw", "throws", "rethrows", "async", "await", "actor", "some", "any",
                "where", "mutating", "nonmutating", "private", "fileprivate", "internal", "public", "open",
                "static", "final", "override", "weak", "unowned", "lazy", "init", "deinit", "self", "Self",
                "true", "false", "nil", "typealias"
            ]
        case "python", "py":
            return [
                "def", "class", "import", "from", "as", "return", "if", "elif", "else", "for", "in", "while",
                "try", "except", "finally", "raise", "with", "async", "await", "lambda", "yield", "global",
                "nonlocal", "pass", "break", "continue", "and", "or", "not", "is", "assert", "True", "False", "None"
            ]
        case "typescript", "ts", "javascript", "js":
            return [
                "function", "const", "let", "var", "return", "if", "else", "switch", "case", "default",
                "for", "while", "do", "try", "catch", "finally", "throw", "import", "export", "from",
                "as", "class", "interface", "type", "extends", "implements", "new", "this", "super",
                "async", "await", "yield", "typeof", "instanceof", "true", "false", "null", "undefined",
                "void", "delete"
            ]
        case "rust", "rs":
            return [
                "fn", "let", "mut", "const", "static", "struct", "enum", "union", "trait", "impl", "type",
                "where", "for", "in", "if", "else", "match", "while", "loop", "return", "break", "continue",
                "use", "pub", "mod", "crate", "super", "self", "Self", "async", "await", "move", "ref",
                "unsafe", "extern", "true", "false", "as"
            ]
        case "go":
            return [
                "func", "var", "const", "type", "struct", "interface", "package", "import", "return",
                "if", "else", "switch", "case", "default", "for", "range", "go", "chan", "select",
                "defer", "map", "make", "new", "len", "cap", "append", "nil", "true", "false"
            ]
        case "c", "cpp", "c++", "h", "hpp":
            return [
                "int", "char", "float", "double", "void", "bool", "long", "short", "unsigned", "signed",
                "auto", "struct", "class", "enum", "union", "typedef", "const", "volatile", "static",
                "extern", "inline", "virtual", "override", "public", "private", "protected", "namespace",
                "using", "template", "typename", "new", "delete", "if", "else", "for", "while", "do",
                "switch", "case", "default", "return", "break", "continue", "sizeof", "true", "false", "nullptr", "NULL"
            ]
        case "java", "kt", "kotlin":
            return [
                "public", "private", "protected", "class", "interface", "enum", "extends", "implements",
                "import", "package", "return", "if", "else", "for", "while", "do", "switch", "case",
                "default", "break", "continue", "new", "this", "super", "try", "catch", "finally", "throw",
                "throws", "static", "final", "void", "val", "var", "fun", "null", "true", "false"
            ]
        case "sql":
            return [
                "SELECT", "FROM", "WHERE", "INSERT", "INTO", "UPDATE", "DELETE", "JOIN", "LEFT", "RIGHT",
                "INNER", "OUTER", "ON", "GROUP", "BY", "ORDER", "HAVING", "LIMIT", "OFFSET", "CREATE",
                "TABLE", "DROP", "ALTER", "ADD", "CONSTRAINT", "PRIMARY", "KEY", "FOREIGN", "REFERENCES",
                "AND", "OR", "NOT", "IN", "IS", "NULL", "AS", "DISTINCT", "UNION", "ALL", "EXISTS", "BETWEEN"
            ]
        default:
            return [
                "func", "function", "def", "var", "let", "const", "return", "if", "else", "for", "in",
                "while", "class", "struct", "import", "export", "true", "false", "null", "nil"
            ]
        }
    }
    
    /// Renders markdown or structured text into a clean printable PDF document.
    func renderMarkdownToPDF(
        markdownText: String,
        title: String? = nil,
        destination: URL
    ) async throws -> URL {
        let destinationFolder = destination.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: destinationFolder, withIntermediateDirectories: true)
        
        let pdfData = NSMutableData()
        var mediaBox = CGRect(x: 0, y: 0, width: 612, height: 792)
        
        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData),
              let pdfContext = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            throw PDFServiceError.writeFailed(destination)
        }
        
        pdfContext.beginPDFPage(nil)
        
        NSGraphicsContext.saveGraphicsState()
        let nsContext = NSGraphicsContext(cgContext: pdfContext, flipped: false)
        NSGraphicsContext.current = nsContext
        
        var currentY: CGFloat = 720.0
        let margin: CGFloat = 54.0
        let contentWidth = mediaBox.width - (margin * 2)
        
        if let title {
            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 22, weight: .bold),
                .foregroundColor: NSColor.black
            ]
            let titleRect = CGRect(x: margin, y: currentY, width: contentWidth, height: 30)
            (title as NSString).draw(in: titleRect, withAttributes: titleAttrs)
            currentY -= 40.0
        }
        
        let bodyFont = NSFont.systemFont(ofSize: 12, weight: .regular)
        let headingFont = NSFont.systemFont(ofSize: 15, weight: .bold)
        
        let lines = markdownText.components(separatedBy: .newlines)
        for line in lines {
            if currentY < 60.0 {
                NSGraphicsContext.restoreGraphicsState()
                pdfContext.endPDFPage()
                pdfContext.beginPDFPage(nil)
                let newContext = NSGraphicsContext(cgContext: pdfContext, flipped: false)
                NSGraphicsContext.current = newContext
                NSGraphicsContext.saveGraphicsState()
                currentY = 720.0
            }
            
            if line.hasPrefix("# ") {
                let text = String(line.dropFirst(2))
                let attrs: [NSAttributedString.Key: Any] = [.font: headingFont, .foregroundColor: NSColor.black]
                (text as NSString).draw(in: CGRect(x: margin, y: currentY, width: contentWidth, height: 22), withAttributes: attrs)
                currentY -= 26.0
            } else {
                let attrs: [NSAttributedString.Key: Any] = [.font: bodyFont, .foregroundColor: NSColor(white: 0.2, alpha: 1.0)]
                (line as NSString).draw(in: CGRect(x: margin, y: currentY, width: contentWidth, height: 18), withAttributes: attrs)
                currentY -= 20.0
            }
        }
        
        NSGraphicsContext.restoreGraphicsState()
        pdfContext.endPDFPage()
        pdfContext.closePDF()
        
        try (pdfData as Data).write(to: destination, options: .atomic)
        return destination
    }
}
