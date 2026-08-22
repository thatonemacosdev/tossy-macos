import Foundation
import PDFKit
import AppKit

enum PDFServiceError: LocalizedError, Sendable {
    case emptyDocumentList
    case documentNotFound(URL)
    case unreadableDocument(URL)
    case invalidPageRange(String)
    case writeFailed(URL)
    case ocrFailed(String)
    case compressionFailed(String)

    var errorDescription: String? {
        switch self {
        case .emptyDocumentList:
            return "No PDF documents were provided."
        case .documentNotFound(let url):
            return "PDF document not found at: \(url.path)"
        case .unreadableDocument(let url):
            return "Unable to open or parse PDF document at: \(url.path)"
        case .invalidPageRange(let details):
            return "Invalid page range specified: \(details)"
        case .writeFailed(let url):
            return "Failed to save generated PDF to: \(url.path)"
        case .ocrFailed(let details):
            return "Optical character recognition failed: \(details)"
        case .compressionFailed(let details):
            return "PDF compression failed: \(details)"
        }
    }
}

struct PageSelection: Sendable {
    let documentURL: URL
    let pageIndex: Int
    
    init(documentURL: URL, pageIndex: Int) {
        self.documentURL = documentURL
        self.pageIndex = pageIndex
    }
}

final class PDFMergeService: Sendable {
    static let shared = PDFMergeService()
    
    init() {}
    
    /// Merges multiple PDF files in order into a single PDF document.
    func merge(
        documents: [URL],
        destination: URL,
        onProgress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> URL {
        guard !documents.isEmpty else {
            throw PDFServiceError.emptyDocumentList
        }
        
        let destinationFolder = destination.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: destinationFolder, withIntermediateDirectories: true)
        let safeDestination = OutputNaming.uniqueDestinationURL(desiredURL: destination)
        
        let mergedDoc = PDFDocument()
        var totalPagesExpected = 0
        
        // Calculate total pages for progress reporting
        for docURL in documents {
            guard FileManager.default.fileExists(atPath: docURL.path) else {
                throw PDFServiceError.documentNotFound(docURL)
            }
            guard let pdf = PDFDocument(url: docURL) else {
                throw PDFServiceError.unreadableDocument(docURL)
            }
            totalPagesExpected += pdf.pageCount
        }
        
        var pagesAdded = 0
        var targetPageIndex = 0
        
        for docURL in documents {
            guard let pdf = PDFDocument(url: docURL) else {
                throw PDFServiceError.unreadableDocument(docURL)
            }
            
            for srcPageIndex in 0..<pdf.pageCount {
                if let page = pdf.page(at: srcPageIndex) {
                    mergedDoc.insert(page, at: targetPageIndex)
                    targetPageIndex += 1
                    pagesAdded += 1
                    
                    if let onProgress, totalPagesExpected > 0 {
                        let progress = Double(pagesAdded) / Double(totalPagesExpected)
                        onProgress(progress)
                    }
                }
            }
        }
        
        guard mergedDoc.pageCount > 0 else {
            throw PDFServiceError.writeFailed(safeDestination)
        }
        
        guard mergedDoc.write(to: safeDestination) else {
            throw PDFServiceError.writeFailed(safeDestination)
        }
        
        return safeDestination
    }
    
    /// Merges an arbitrary list of specific pages from multiple documents in custom order.
    func mergeCustomPageOrder(
        selections: [PageSelection],
        destination: URL
    ) async throws -> URL {
        guard !selections.isEmpty else {
            throw PDFServiceError.emptyDocumentList
        }
        
        let destinationFolder = destination.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: destinationFolder, withIntermediateDirectories: true)
        let safeDestination = OutputNaming.uniqueDestinationURL(desiredURL: destination)
        
        // Cache loaded documents to avoid reloading the same file repeatedly
        var docCache: [URL: PDFDocument] = [:]
        for selection in selections {
            if docCache[selection.documentURL] == nil {
                guard let doc = PDFDocument(url: selection.documentURL) else {
                    throw PDFServiceError.unreadableDocument(selection.documentURL)
                }
                docCache[selection.documentURL] = doc
            }
        }
        
        let outputDoc = PDFDocument()
        var targetIndex = 0
        
        for sel in selections {
            guard let srcDoc = docCache[sel.documentURL] else {
                throw PDFServiceError.unreadableDocument(sel.documentURL)
            }
            guard sel.pageIndex >= 0 && sel.pageIndex < srcDoc.pageCount else {
                throw PDFServiceError.invalidPageRange("Page index \(sel.pageIndex) out of bounds for \(sel.documentURL.lastPathComponent)")
            }
            if let page = srcDoc.page(at: sel.pageIndex) {
                outputDoc.insert(page, at: targetIndex)
                targetIndex += 1
            }
        }
        
        guard outputDoc.pageCount > 0 else {
            throw PDFServiceError.writeFailed(safeDestination)
        }
        
        guard outputDoc.write(to: safeDestination) else {
            throw PDFServiceError.writeFailed(safeDestination)
        }
        
        return safeDestination
    }
}
