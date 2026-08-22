import Foundation
import Vision
import PDFKit
import AppKit

struct OCRPageResult: Sendable {
    let pageIndex: Int
    let fullText: String
    let lines: [String]
    
    init(pageIndex: Int, fullText: String, lines: [String]) {
        self.pageIndex = pageIndex
        self.fullText = fullText
        self.lines = lines
    }
}

struct OCRDocumentResult: Sendable {
    let sourceURL: URL
    let pages: [OCRPageResult]
    
    var combinedText: String {
        pages.map(\.fullText).joined(separator: "\n\n--- Page Break ---\n\n")
    }
    
    var totalCharacterCount: Int {
        combinedText.count
    }
    
    var totalWordCount: Int {
        combinedText.split { $0.isWhitespace || $0.isNewline }.count
    }
}

final class VisionOCRService: Sendable {
    static let shared = VisionOCRService()
    
    init() {}
    
    /// Extracts text from an image or multi-page PDF using Apple's on-device Vision OCR engine.
    func extractText(
        from url: URL,
        recognitionLevel: VNRequestTextRecognitionLevel = .accurate,
        customLanguages: [String] = ["en-US", "es-ES", "fr-FR", "de-DE", "zh-Hans", "ja-JP"],
        onProgress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> OCRDocumentResult {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw PDFServiceError.documentNotFound(url)
        }
        
        let ext = url.pathExtension.lowercased()
        if ext == "pdf" {
            return try await extractTextFromPDF(
                url: url,
                recognitionLevel: recognitionLevel,
                customLanguages: customLanguages,
                onProgress: onProgress
            )
        } else {
            let pageResult = try await extractTextFromImageFile(
                url: url,
                pageIndex: 0,
                recognitionLevel: recognitionLevel,
                customLanguages: customLanguages
            )
            onProgress?(1.0)
            return OCRDocumentResult(sourceURL: url, pages: [pageResult])
        }
    }
    
    /// Extracts text and saves it as a UTF-8 `.txt` document.
    func exportToTextFile(from url: URL, destinationURL: URL) async throws -> URL {
        let result = try await extractText(from: url)
        let folder = destinationURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try result.combinedText.write(to: destinationURL, atomically: true, encoding: .utf8)
        return destinationURL
    }
    
    /// Extracts text and formats it cleanly as a Markdown (`.md`) document with headings.
    func exportToMarkdown(from url: URL, destinationURL: URL) async throws -> URL {
        let result = try await extractText(from: url)
        let folder = destinationURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        
        var md = "# OCR Extracted Text: \(url.lastPathComponent)\n\n"
        md += "*Extracted on-device via Tossy Apple Vision OCR Engine*\n\n"
        
        for page in result.pages {
            md += "## Page \(page.pageIndex + 1)\n\n"
            md += page.fullText
            md += "\n\n"
        }
        
        try md.write(to: destinationURL, atomically: true, encoding: .utf8)
        return destinationURL
    }
    
    private func extractTextFromPDF(
        url: URL,
        recognitionLevel: VNRequestTextRecognitionLevel,
        customLanguages: [String],
        onProgress: (@Sendable (Double) -> Void)?
    ) async throws -> OCRDocumentResult {
        guard let doc = PDFDocument(url: url) else {
            throw PDFServiceError.unreadableDocument(url)
        }
        guard doc.pageCount > 0 else {
            throw PDFServiceError.invalidPageRange("PDF contains zero pages")
        }
        
        var pageResults: [OCRPageResult] = []
        let totalPages = doc.pageCount
        
        for i in 0..<totalPages {
            guard let page = doc.page(at: i) else { continue }
            
            if let existingText = page.string, !existingText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let lines = existingText.components(separatedBy: .newlines).filter { !$0.isEmpty }
                pageResults.append(OCRPageResult(pageIndex: i, fullText: existingText, lines: lines))
            } else {
                let bounds = page.bounds(for: .mediaBox)
                let scale: CGFloat = 2.0
                let width = Int(bounds.width * scale)
                let height = Int(bounds.height * scale)
                
                let colorSpace = CGColorSpaceCreateDeviceRGB()
                let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
                
                if let context = CGContext(
                    data: nil,
                    width: width,
                    height: height,
                    bitsPerComponent: 8,
                    bytesPerRow: width * 4,
                    space: colorSpace,
                    bitmapInfo: bitmapInfo
                ) {
                    context.setFillColor(NSColor.white.cgColor)
                    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
                    context.scaleBy(x: scale, y: scale)
                    page.draw(with: .mediaBox, to: context)
                    
                    if let cgImage = context.makeImage() {
                        let pageOCR = try await performVisionOCR(
                            on: cgImage,
                            pageIndex: i,
                            recognitionLevel: recognitionLevel,
                            customLanguages: customLanguages
                        )
                        pageResults.append(pageOCR)
                    }
                }
            }
            
            if let onProgress {
                onProgress(Double(i + 1) / Double(totalPages))
            }
        }
        
        return OCRDocumentResult(sourceURL: url, pages: pageResults)
    }
    
    private func extractTextFromImageFile(
        url: URL,
        pageIndex: Int,
        recognitionLevel: VNRequestTextRecognitionLevel,
        customLanguages: [String]
    ) async throws -> OCRPageResult {
        guard let nsImage = NSImage(contentsOf: url),
              let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw PDFServiceError.unreadableDocument(url)
        }
        
        return try await performVisionOCR(
            on: cgImage,
            pageIndex: pageIndex,
            recognitionLevel: recognitionLevel,
            customLanguages: customLanguages
        )
    }
    
    private func performVisionOCR(
        on cgImage: CGImage,
        pageIndex: Int,
        recognitionLevel: VNRequestTextRecognitionLevel,
        customLanguages: [String]
    ) async throws -> OCRPageResult {
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: PDFServiceError.ocrFailed(error.localizedDescription))
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: OCRPageResult(pageIndex: pageIndex, fullText: "", lines: []))
                    return
                }
                
                var lines: [String] = []
                for observation in observations {
                    guard let topCandidate = observation.topCandidates(1).first else { continue }
                    lines.append(topCandidate.string)
                }
                
                let combined = lines.joined(separator: "\n")
                continuation.resume(returning: OCRPageResult(pageIndex: pageIndex, fullText: combined, lines: lines))
            }
            
            request.recognitionLevel = recognitionLevel
            request.usesLanguageCorrection = true
            request.recognitionLanguages = customLanguages
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: PDFServiceError.ocrFailed(error.localizedDescription))
            }
        }
    }
}
