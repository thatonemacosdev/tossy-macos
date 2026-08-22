import Foundation
import PDFKit
import AppKit

final class PDFSplitService: Sendable {
    static let shared = PDFSplitService()
    
    init() {}
    
    /// Parses range strings such as "1-5, 8, 10-12" or "1, 3, 5" into validated ClosedRanges (1-indexed).
    func parsePageRanges(text: String, totalPages: Int) -> [ClosedRange<Int>] {
        let segments = text.components(separatedBy: ",")
        var ranges: [ClosedRange<Int>] = []
        
        for segment in segments {
            let trimmed = segment.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }
            
            if trimmed.contains("-") {
                let parts = trimmed.components(separatedBy: "-")
                if parts.count == 2,
                   let start = Int(parts[0].trimmingCharacters(in: .whitespaces)),
                   let end = Int(parts[1].trimmingCharacters(in: .whitespaces)) {
                    let boundedStart = max(1, min(start, totalPages))
                    let boundedEnd = max(boundedStart, min(end, totalPages))
                    if boundedStart <= boundedEnd {
                        ranges.append(boundedStart...boundedEnd)
                    }
                }
            } else if let singlePage = Int(trimmed) {
                let boundedPage = max(1, min(singlePage, totalPages))
                ranges.append(boundedPage...boundedPage)
            }
        }
        
        return ranges
    }
    
    /// Splits a PDF document into multiple smaller PDF files by page ranges (1-indexed).
    func splitByRanges(
        source: URL,
        ranges: [ClosedRange<Int>],
        destinationFolder: URL
    ) async throws -> [URL] {
        guard FileManager.default.fileExists(atPath: source.path) else {
            throw PDFServiceError.documentNotFound(source)
        }
        guard let doc = PDFDocument(url: source) else {
            throw PDFServiceError.unreadableDocument(source)
        }
        guard !ranges.isEmpty else {
            throw PDFServiceError.invalidPageRange("No valid page ranges provided")
        }
        
        try? FileManager.default.createDirectory(at: destinationFolder, withIntermediateDirectories: true)
        let baseName = source.deletingPathExtension().lastPathComponent
        var outputURLs: [URL] = []
        
        for (rangeIndex, range) in ranges.enumerated() {
            guard range.lowerBound >= 1 && range.upperBound <= doc.pageCount && range.lowerBound <= range.upperBound else {
                throw PDFServiceError.invalidPageRange("Range \(range.lowerBound)-\(range.upperBound) is outside document bounds (1-\(doc.pageCount))")
            }
            
            let splitDoc = PDFDocument()
            var destIndex = 0
            
            for pageNum in range {
                if let page = doc.page(at: pageNum - 1) {
                    splitDoc.insert(page, at: destIndex)
                    destIndex += 1
                }
            }
            
            let rangeLabel = range.lowerBound == range.upperBound ? "p\(range.lowerBound)" : "p\(range.lowerBound)-p\(range.upperBound)"
            let outName = "\(baseName)_part_\(rangeIndex + 1)_\(rangeLabel).pdf"
            let desiredURL = destinationFolder.appendingPathComponent(outName)
            let outURL = OutputNaming.uniqueDestinationURL(desiredURL: desiredURL)
            
            guard splitDoc.write(to: outURL) else {
                throw PDFServiceError.writeFailed(outURL)
            }
            outputURLs.append(outURL)
        }
        
        return outputURLs
    }
    
    /// Extracts a specific set of pages (1-indexed) into a single new PDF document.
    func extractPages(
        source: URL,
        pageIndices: [Int],
        destination: URL
    ) async throws -> URL {
        guard FileManager.default.fileExists(atPath: source.path) else {
            throw PDFServiceError.documentNotFound(source)
        }
        guard let doc = PDFDocument(url: source) else {
            throw PDFServiceError.unreadableDocument(source)
        }
        guard !pageIndices.isEmpty else {
            throw PDFServiceError.invalidPageRange("No page indices specified for extraction")
        }
        
        let destinationFolder = destination.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: destinationFolder, withIntermediateDirectories: true)
        let safeDestination = OutputNaming.uniqueDestinationURL(desiredURL: destination)
        
        let extractDoc = PDFDocument()
        var destIndex = 0
        
        for pageNum in pageIndices {
            guard pageNum >= 1 && pageNum <= doc.pageCount else {
                throw PDFServiceError.invalidPageRange("Page index \(pageNum) out of bounds (1-\(doc.pageCount))")
            }
            if let page = doc.page(at: pageNum - 1) {
                extractDoc.insert(page, at: destIndex)
                destIndex += 1
            }
        }
        
        guard extractDoc.pageCount > 0 else {
            throw PDFServiceError.writeFailed(safeDestination)
        }
        
        guard extractDoc.write(to: safeDestination) else {
            throw PDFServiceError.writeFailed(safeDestination)
        }
        
        return safeDestination
    }
    
    /// Bursts every page in the PDF into a separate single-page PDF document.
    func burst(
        source: URL,
        destinationFolder: URL,
        onProgress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> [URL] {
        guard FileManager.default.fileExists(atPath: source.path) else {
            throw PDFServiceError.documentNotFound(source)
        }
        guard let doc = PDFDocument(url: source) else {
            throw PDFServiceError.unreadableDocument(source)
        }
        guard doc.pageCount > 0 else {
            throw PDFServiceError.invalidPageRange("Document contains zero pages")
        }
        
        try? FileManager.default.createDirectory(at: destinationFolder, withIntermediateDirectories: true)
        let baseName = source.deletingPathExtension().lastPathComponent
        var outputURLs: [URL] = []
        let totalPages = doc.pageCount
        
        for i in 0..<totalPages {
            guard let page = doc.page(at: i) else { continue }
            let singleDoc = PDFDocument()
            singleDoc.insert(page, at: 0)
            
            let pageFormatted = String(format: "%03d", i + 1)
            let desiredURL = destinationFolder.appendingPathComponent("\(baseName)_page_\(pageFormatted).pdf")
            let outURL = OutputNaming.uniqueDestinationURL(desiredURL: desiredURL)
            
            guard singleDoc.write(to: outURL) else {
                throw PDFServiceError.writeFailed(outURL)
            }
            outputURLs.append(outURL)
            
            if let onProgress {
                onProgress(Double(i + 1) / Double(totalPages))
            }
        }
        
        return outputURLs
    }
}
