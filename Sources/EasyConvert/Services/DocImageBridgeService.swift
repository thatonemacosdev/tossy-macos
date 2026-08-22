import Foundation
import PDFKit
import AppKit
import CoreGraphics

enum PDFPageFitMode: String, CaseIterable, Identifiable, Sendable {
    case a4 = "A4 (Standard 210 x 297 mm)"
    case letter = "US Letter (8.5 x 11 in)"
    case fitToImage = "Original Image Dimensions"
    
    var id: String { rawValue }
    
    var sizePoints: CGSize? {
        switch self {
        case .a4: return CGSize(width: 595.28, height: 841.89)
        case .letter: return CGSize(width: 612.0, height: 792.0)
        case .fitToImage: return nil
        }
    }
}

final class DocImageBridgeService: Sendable {
    static let shared = DocImageBridgeService()
    
    init() {}
    
    /// Converts each page of a PDF into high-DPI image files in the target format (PNG, JPEG, WebP, etc.).
    func pdfToImages(
        pdfURL: URL,
        format: ImageFormat = .png,
        dpi: CGFloat = 300.0,
        destinationFolder: URL,
        onProgress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> [URL] {
        guard FileManager.default.fileExists(atPath: pdfURL.path) else {
            throw PDFServiceError.documentNotFound(pdfURL)
        }
        guard let doc = PDFDocument(url: pdfURL) else {
            throw PDFServiceError.unreadableDocument(pdfURL)
        }
        guard doc.pageCount > 0 else {
            throw PDFServiceError.invalidPageRange("PDF contains 0 pages")
        }
        
        try? FileManager.default.createDirectory(at: destinationFolder, withIntermediateDirectories: true)
        let baseName = pdfURL.deletingPathExtension().lastPathComponent
        var outputURLs: [URL] = []
        let totalPages = doc.pageCount
        
        for i in 0..<totalPages {
            guard let page = doc.page(at: i) else { continue }
            let pageBounds = page.bounds(for: .mediaBox)
            let scaleFactor = dpi / 72.0
            let pixelWidth = max(1, Int(pageBounds.width * scaleFactor))
            let pixelHeight = max(1, Int(pageBounds.height * scaleFactor))
            
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
            
            guard let bitmapContext = CGContext(
                data: nil,
                width: pixelWidth,
                height: pixelHeight,
                bitsPerComponent: 8,
                bytesPerRow: pixelWidth * 4,
                space: colorSpace,
                bitmapInfo: bitmapInfo
            ) else {
                continue
            }
            
            bitmapContext.setFillColor(NSColor.white.cgColor)
            bitmapContext.fill(CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))
            bitmapContext.scaleBy(x: scaleFactor, y: scaleFactor)
            page.draw(with: .mediaBox, to: bitmapContext)
            
            guard let cgImage = bitmapContext.makeImage() else { continue }
            let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: pixelWidth, height: pixelHeight))
            
            let pageStr = String(format: "%03d", i + 1)
            let rawPngURL = destinationFolder.appendingPathComponent("\(baseName)_page_\(pageStr).png")
            
            guard let tiff = nsImage.tiffRepresentation,
                  let bitmapRep = NSBitmapImageRep(data: tiff),
                  let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
                continue
            }
            
            try pngData.write(to: rawPngURL, options: .atomic)
            
            if format == .png {
                outputURLs.append(rawPngURL)
            } else {
                let res = try await ImageConverter().convert(sourceURL: rawPngURL, to: format, destinationFolder: destinationFolder)
                outputURLs.append(contentsOf: res.outputURLs)
                try? FileManager.default.removeItem(at: rawPngURL)
            }
            
            if let onProgress {
                onProgress(Double(i + 1) / Double(totalPages))
            }
        }
        
        return outputURLs
    }
    
    /// Compiles a collection of arbitrary images into a unified multi-page PDF document.
    func imagesToPDF(
        imageURLs: [URL],
        pageFitMode: PDFPageFitMode = .fitToImage,
        destinationURL: URL,
        onProgress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> URL {
        guard !imageURLs.isEmpty else {
            throw PDFServiceError.emptyDocumentList
        }
        
        let destinationFolder = destinationURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: destinationFolder, withIntermediateDirectories: true)
        
        let pdfDoc = PDFDocument()
        var pageIndex = 0
        let total = imageURLs.count
        
        for (idx, imgURL) in imageURLs.enumerated() {
            guard let nsImage = NSImage(contentsOf: imgURL) else { continue }
            guard let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else { continue }
            
            let imgSize = CGSize(width: cgImage.width, height: cgImage.height)
            let targetPageSize: CGSize = pageFitMode.sizePoints ?? CGSize(width: max(1, imgSize.width * 0.72), height: max(1, imgSize.height * 0.72))
            
            if let pdfPage = PDFPage(image: nsImage) {
                pdfPage.setBounds(CGRect(origin: .zero, size: targetPageSize), for: .mediaBox)
                pdfDoc.insert(pdfPage, at: pageIndex)
                pageIndex += 1
            }
            
            if let onProgress {
                onProgress(Double(idx + 1) / Double(total))
            }
        }
        
        guard pdfDoc.pageCount > 0 else {
            throw PDFServiceError.writeFailed(destinationURL)
        }
        
        guard pdfDoc.write(to: destinationURL) else {
            throw PDFServiceError.writeFailed(destinationURL)
        }
        
        return destinationURL
    }
}
