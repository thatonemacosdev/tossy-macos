import Foundation
import PDFKit
import CoreGraphics
import AppKit

enum PDFCompressionPreset: String, CaseIterable, Identifiable, Sendable {
    case low = "Light Compression (High Quality 200 DPI)"
    case medium = "Balanced (Email Friendly 150 DPI)"
    case high = "Maximum Compression (Smallest Size 96 DPI)"
    case targetSize = "Fit to Target Size"
    
    var id: String { rawValue }
    
    var targetDPI: CGFloat {
        switch self {
        case .low: return 200.0
        case .medium: return 150.0
        case .high: return 96.0
        case .targetSize: return 120.0
        }
    }
    
    var imageQuality: CGFloat {
        switch self {
        case .low: return 0.85
        case .medium: return 0.65
        case .high: return 0.45
        case .targetSize: return 0.60
        }
    }
}

struct PDFCompressionResult: Sendable {
    let outputURL: URL
    let originalSizeBytes: Int64
    let compressedSizeBytes: Int64
    
    var savingsBytes: Int64 {
        max(0, originalSizeBytes - compressedSizeBytes)
    }
    
    var savingsRatioPercent: Double {
        guard originalSizeBytes > 0 else { return 0 }
        let diff = Double(originalSizeBytes - compressedSizeBytes)
        return max(0, (diff / Double(originalSizeBytes)) * 100.0)
    }
}

final class PDFCompressService: Sendable {
    static let shared = PDFCompressService()
    
    init() {}
    
    /// Compresses a PDF document according to preset or explicit target size in bytes.
    func compress(
        source: URL,
        preset: PDFCompressionPreset = .medium,
        targetSizeBytes: Int64? = nil,
        destination: URL,
        onProgress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> PDFCompressionResult {
        guard FileManager.default.fileExists(atPath: source.path) else {
            throw PDFServiceError.documentNotFound(source)
        }
        guard let doc = PDFDocument(url: source) else {
            throw PDFServiceError.unreadableDocument(source)
        }
        guard doc.pageCount > 0 else {
            throw PDFServiceError.invalidPageRange("PDF has 0 pages")
        }
        
        let originalSize = (try? FileManager.default.attributesOfItem(atPath: source.path)[.size] as? Int64) ?? 0
        let destinationFolder = destination.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: destinationFolder, withIntermediateDirectories: true)
        
        var currentDPI = preset.targetDPI
        var currentQuality = preset.imageQuality
        
        if let targetSizeBytes, targetSizeBytes > 0 && originalSize > targetSizeBytes {
            let ratio = Double(targetSizeBytes) / Double(originalSize)
            if ratio < 0.3 {
                currentDPI = 72.0
                currentQuality = 0.35
            } else if ratio < 0.6 {
                currentDPI = 110.0
                currentQuality = 0.50
            } else {
                currentDPI = 150.0
                currentQuality = 0.70
            }
        }
        
        let outputData = try renderCompressedPDF(
            from: doc,
            dpi: currentDPI,
            compressionQuality: currentQuality,
            onProgress: onProgress
        )
        
        let safeDestination = OutputNaming.uniqueDestinationURL(desiredURL: destination)
        try outputData.write(to: safeDestination, options: .atomic)
        
        let finalSize = (try? FileManager.default.attributesOfItem(atPath: safeDestination.path)[.size] as? Int64) ?? Int64(outputData.count)
        
        return PDFCompressionResult(
            outputURL: safeDestination,
            originalSizeBytes: originalSize,
            compressedSizeBytes: finalSize
        )
    }
    
    private func renderCompressedPDF(
        from doc: PDFDocument,
        dpi: CGFloat,
        compressionQuality: CGFloat,
        onProgress: (@Sendable (Double) -> Void)?
    ) throws -> Data {
        let pdfData = NSMutableData()
        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData) else {
            throw PDFServiceError.compressionFailed("Could not allocate CoreGraphics PDF data consumer")
        }
        
        let totalPages = doc.pageCount
        var pdfContext: CGContext?
        
        for i in 0..<totalPages {
            guard let page = doc.page(at: i) else { continue }
            let pageBounds = page.bounds(for: .mediaBox)
            var mediaBox = pageBounds
            
            if pdfContext == nil {
                pdfContext = CGContext(consumer: consumer, mediaBox: &mediaBox, nil)
            }
            
            guard let context = pdfContext else {
                throw PDFServiceError.compressionFailed("Failed to initialize CGContext for PDF rendering")
            }
            
            context.beginPDFPage(nil)
            
            let scaleFactor = dpi / 72.0
            let pixelWidth = max(1, Int(pageBounds.width * scaleFactor))
            let pixelHeight = max(1, Int(pageBounds.height * scaleFactor))
            
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
            
            if let bitmapContext = CGContext(
                data: nil,
                width: pixelWidth,
                height: pixelHeight,
                bitsPerComponent: 8,
                bytesPerRow: pixelWidth * 4,
                space: colorSpace,
                bitmapInfo: bitmapInfo
            ) {
                bitmapContext.setFillColor(NSColor.white.cgColor)
                bitmapContext.fill(CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))
                
                bitmapContext.saveGState()
                bitmapContext.scaleBy(x: scaleFactor, y: scaleFactor)
                page.draw(with: .mediaBox, to: bitmapContext)
                bitmapContext.restoreGState()
                
                if let rawImage = bitmapContext.makeImage() {
                    let nsImage = NSImage(cgImage: rawImage, size: NSSize(width: pixelWidth, height: pixelHeight))
                    if let tiffData = nsImage.tiffRepresentation,
                       let bitmapRep = NSBitmapImageRep(data: tiffData),
                       let jpegData = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: compressionQuality]),
                       let imageSource = CGImageSourceCreateWithData(jpegData as CFData, nil),
                       let compressedImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) {
                        context.draw(compressedImage, in: pageBounds)
                    } else {
                        context.draw(rawImage, in: pageBounds)
                    }
                }
            } else {
                page.draw(with: .mediaBox, to: context)
            }
            
            context.endPDFPage()
            
            if let onProgress {
                onProgress(Double(i + 1) / Double(totalPages))
            }
        }
        
        pdfContext?.closePDF()
        
        guard pdfData.length > 0 else {
            throw PDFServiceError.compressionFailed("Generated PDF data was empty")
        }
        
        return pdfData as Data
    }
}
