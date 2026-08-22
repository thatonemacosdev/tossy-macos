import Foundation
import AppKit
import PDFKit

enum CodeCardTheme: String, CaseIterable, Identifiable, Sendable {
    case darkTitanium = "Dark Titanium"
    case lightMinimal = "Light Minimal"
    case matrixGreen = "Matrix Terminal"
    
    var id: String { rawValue }
    
    var backgroundColor: NSColor {
        switch self {
        case .darkTitanium: return NSColor(white: 0.08, alpha: 1.0)
        case .lightMinimal: return NSColor(white: 0.97, alpha: 1.0)
        case .matrixGreen: return NSColor(red: 0.02, green: 0.05, blue: 0.02, alpha: 1.0)
        }
    }
    
    var textColor: NSColor {
        switch self {
        case .darkTitanium: return NSColor(white: 0.92, alpha: 1.0)
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

final class MarkdownCodeExportService: Sendable {
    static let shared = MarkdownCodeExportService()
    
    init() {}
    
    /// Renders source code snippet into a high-res PNG image card with macOS window chrome.
    func renderCodeCard(
        sourceCode: String,
        language: String = "swift",
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
        
        let lineHeight: CGFloat = 20.0
        let headerHeight: CGFloat = 40.0
        let padding: CGFloat = 24.0
        let lineNumWidth: CGFloat = 42.0
        
        var maxLineWidth: CGFloat = 400.0
        for line in lines {
            let width = (line as NSString).size(withAttributes: [.font: font]).width
            if width > maxLineWidth { maxLineWidth = width }
        }
        
        let totalWidth = max(550.0, maxLineWidth + lineNumWidth + (padding * 2) + 20.0)
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
        
        // Window Control Buttons (Red / Yellow / Green dots)
        let dotY = totalHeight - 24.0
        let redDot = NSBezierPath(ovalIn: CGRect(x: padding, y: dotY, width: 11, height: 11))
        NSColor(red: 1.0, green: 0.36, blue: 0.33, alpha: 1.0).setFill()
        redDot.fill()
        
        let yellowDot = NSBezierPath(ovalIn: CGRect(x: padding + 18, y: dotY, width: 11, height: 11))
        NSColor(red: 1.0, green: 0.74, blue: 0.18, alpha: 1.0).setFill()
        yellowDot.fill()
        
        let greenDot = NSBezierPath(ovalIn: CGRect(x: padding + 36, y: dotY, width: 11, height: 11))
        NSColor(red: 0.18, green: 0.80, blue: 0.33, alpha: 1.0).setFill()
        greenDot.fill()
        
        // Title in header
        let displayTitle = title ?? "\(language.lowercased()) file"
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: headerFont,
            .foregroundColor: theme.textColor.withAlphaComponent(0.6)
        ]
        let titleSize = (displayTitle as NSString).size(withAttributes: titleAttrs)
        let titleRect = CGRect(
            x: (totalWidth - titleSize.width) / 2.0,
            y: dotY - 2.0,
            width: titleSize.width,
            height: titleSize.height
        )
        (displayTitle as NSString).draw(in: titleRect, withAttributes: titleAttrs)
        
        // Render lines with line numbers
        var currentY = totalHeight - headerHeight - padding
        
        for (index, line) in lines.enumerated() {
            let lineNumStr = String(format: "%d", index + 1)
            let lineNumAttrs: [NSAttributedString.Key: Any] = [
                .font: lineNumFont,
                .foregroundColor: theme.lineNumberColor
            ]
            let lineNumRect = CGRect(x: padding, y: currentY - 14.0, width: lineNumWidth, height: lineHeight)
            (lineNumStr as NSString).draw(in: lineNumRect, withAttributes: lineNumAttrs)
            
            let codeAttrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: theme.textColor
            ]
            let codeRect = CGRect(x: padding + lineNumWidth, y: currentY - 14.0, width: totalWidth - padding - lineNumWidth, height: lineHeight)
            (line as NSString).draw(in: codeRect, withAttributes: codeAttrs)
            
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
