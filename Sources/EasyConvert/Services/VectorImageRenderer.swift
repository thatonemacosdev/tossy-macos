import AppKit
import CoreGraphics
import UniformTypeIdentifiers

enum VectorRenderError: LocalizedError {
    case unsupported
    case renderFailed

    var errorDescription: String? {
        switch self {
        case .unsupported: return "This vector/document format couldn't be rasterized (EPS and AI files that aren't PDF-compatible aren't supported)."
        case .renderFailed: return "Failed to render this file to an image."
        }
    }
}

/// Rasterizes vector and document sources  -  SVG, PDF (one image per page), and EPS/AI files
/// that are PDF-compatible (Illustrator's default save format)  -  into bitmap images.
enum VectorImageRenderer {
    static func isVectorOrDocumentSource(at url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        if ext == "svg" || ext == "pdf" || ext == "eps" || ext == "ai" { return true }
        guard let type = UTType(filenameExtension: ext) else { return false }
        return type.conforms(to: .svg) || type.conforms(to: .pdf)
    }

    /// Renders every page (PDF) or the single artwork (SVG/EPS/AI) to a CGImage at `scale`x
    /// the document's point size.
    static func render(url: URL, scale: CGFloat = 2.0) throws -> [CGImage] {
        if url.pathExtension.lowercased() == "svg" {
            guard let image = renderSVG(url: url, scale: scale) else { throw VectorRenderError.renderFailed }
            return [image]
        }
        // PDF, EPS, and (often) AI files are all PDF-compatible containers.
        if let pages = renderPDF(url: url, scale: scale), !pages.isEmpty {
            return pages
        }
        throw VectorRenderError.unsupported
    }

    private static func renderSVG(url: URL, scale: CGFloat) -> CGImage? {
        guard let nsImage = NSImage(contentsOf: url), nsImage.size.width > 0, nsImage.size.height > 0 else { return nil }
        let pixelSize = CGSize(width: nsImage.size.width * scale, height: nsImage.size.height * scale)

        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(pixelSize.width),
            pixelsHigh: Int(pixelSize.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { return nil }

        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        nsImage.draw(in: CGRect(origin: .zero, size: pixelSize))
        return bitmap.cgImage
    }

    private static func renderPDF(url: URL, scale: CGFloat) -> [CGImage]? {
        guard let document = CGPDFDocument(url as CFURL), document.numberOfPages > 0 else { return nil }
        var images: [CGImage] = []

        for pageIndex in 1...document.numberOfPages {
            guard let page = document.page(at: pageIndex) else { continue }
            let mediaBox = page.getBoxRect(.mediaBox)
            let pixelWidth = max(Int(mediaBox.width * scale), 1)
            let pixelHeight = max(Int(mediaBox.height * scale), 1)

            guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
                  let context = CGContext(
                    data: nil,
                    width: pixelWidth,
                    height: pixelHeight,
                    bitsPerComponent: 8,
                    bytesPerRow: 0,
                    space: colorSpace,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                  ) else { continue }

            context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))
            context.scaleBy(x: scale, y: scale)
            context.drawPDFPage(page)

            if let image = context.makeImage() {
                images.append(image)
            }
        }
        return images
    }
}
