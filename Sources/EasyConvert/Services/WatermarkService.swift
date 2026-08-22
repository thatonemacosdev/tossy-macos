import Foundation
import AppKit
import CoreGraphics

enum WatermarkAnchor: String, CaseIterable, Identifiable, Sendable {
    case topLeft = "Top Left"
    case topRight = "Top Right"
    case bottomLeft = "Bottom Left"
    case bottomRight = "Bottom Right"
    case center = "Center"
    case tile = "Repeated Tile"
    
    var id: String { rawValue }
}

final class WatermarkService: Sendable {
    static let shared = WatermarkService()
    
    init() {}
    
    /// Renders a transparent text badge into a PNG image for universal overlay.
    private func renderTextWatermarkImage(
        text: String,
        opacity: CGFloat = 0.7,
        fontSize: CGFloat = 24.0
    ) -> URL? {
        let font = NSFont.systemFont(ofSize: fontSize, weight: .bold)
        let textColor = NSColor.white.withAlphaComponent(opacity)
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(opacity * 0.8)
        shadow.shadowOffset = NSSize(width: 1.5, height: -1.5)
        shadow.shadowBlurRadius = 3.0
        
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor,
            .shadow: shadow
        ]
        
        let textSize = (text as NSString).size(withAttributes: attrs)
        let width = Int(ceil(textSize.width + 20))
        let height = Int(ceil(textSize.height + 20))
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        
        NSGraphicsContext.saveGraphicsState()
        let nsContext = NSGraphicsContext(cgContext: context, flipped: false)
        NSGraphicsContext.current = nsContext
        (text as NSString).draw(at: CGPoint(x: 10, y: 10), withAttributes: attrs)
        NSGraphicsContext.restoreGraphicsState()
        
        guard let cgImage = context.makeImage() else { return nil }
        let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: width, height: height))
        guard let tiff = nsImage.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else { return nil }
        
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("wm_\(UUID().uuidString).png")
        try? png.write(to: tempURL)
        return tempURL
    }
    
    /// Applies a customizable text watermark over an image.
    func applyTextWatermark(
        imageURL: URL,
        text: String,
        anchor: WatermarkAnchor = .bottomRight,
        opacity: CGFloat = 0.65,
        fontSize: CGFloat = 24.0,
        destinationURL: URL
    ) async throws -> URL {
        guard FileManager.default.fileExists(atPath: imageURL.path) else {
            throw MediaStudioError.fileNotFound(imageURL)
        }
        guard let nsImage = NSImage(contentsOf: imageURL),
              let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw MediaStudioError.executionFailed("Unable to decode source image")
        }
        
        let destFolder = destinationURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: destFolder, withIntermediateDirectories: true)
        let safeDestination = OutputNaming.uniqueDestinationURL(desiredURL: destinationURL)
        
        let width = cgImage.width
        let height = cgImage.height
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            throw MediaStudioError.executionFailed("Could not allocate graphics context")
        }
        
        // Draw base image
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        NSGraphicsContext.saveGraphicsState()
        let nsContext = NSGraphicsContext(cgContext: context, flipped: false)
        NSGraphicsContext.current = nsContext
        
        let font = NSFont.systemFont(ofSize: fontSize, weight: .bold)
        let textColor = NSColor.white.withAlphaComponent(opacity)
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(opacity * 0.8)
        shadow.shadowOffset = NSSize(width: 1.5, height: -1.5)
        shadow.shadowBlurRadius = 3.0
        
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor,
            .shadow: shadow
        ]
        
        let textSize = (text as NSString).size(withAttributes: attrs)
        let padding: CGFloat = 28.0
        
        if anchor == .tile {
            // Repeated diagonal tile
            let stepX = textSize.width + 80.0
            let stepY = textSize.height + 60.0
            var y: CGFloat = 0
            while y < CGFloat(height) + stepY {
                var x: CGFloat = 0
                while x < CGFloat(width) + stepX {
                    (text as NSString).draw(at: CGPoint(x: x, y: y), withAttributes: attrs)
                    x += stepX
                }
                y += stepY
            }
        } else {
            let point: CGPoint
            switch anchor {
            case .topLeft:
                point = CGPoint(x: padding, y: CGFloat(height) - textSize.height - padding)
            case .topRight:
                point = CGPoint(x: CGFloat(width) - textSize.width - padding, y: CGFloat(height) - textSize.height - padding)
            case .bottomLeft:
                point = CGPoint(x: padding, y: padding)
            case .bottomRight:
                point = CGPoint(x: CGFloat(width) - textSize.width - padding, y: padding)
            case .center:
                point = CGPoint(x: (CGFloat(width) - textSize.width) / 2.0, y: (CGFloat(height) - textSize.height) / 2.0)
            case .tile:
                point = .zero
            }
            (text as NSString).draw(at: point, withAttributes: attrs)
        }
        
        NSGraphicsContext.restoreGraphicsState()
        
        guard let outputCGImage = context.makeImage() else {
            throw MediaStudioError.executionFailed("Failed to make output image")
        }
        
        let outNSImage = NSImage(cgImage: outputCGImage, size: NSSize(width: width, height: height))
        guard let tiffData = outNSImage.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            throw MediaStudioError.executionFailed("Failed to encode PNG output")
        }
        
        try pngData.write(to: safeDestination, options: .atomic)
        return safeDestination
    }
    
    /// Applies an image/logo watermark over an image.
    func applyImageWatermark(
        imageURL: URL,
        logoURL: URL,
        anchor: WatermarkAnchor = .bottomRight,
        opacity: CGFloat = 0.8,
        scalePercent: CGFloat = 20.0,
        destinationURL: URL
    ) async throws -> URL {
        guard FileManager.default.fileExists(atPath: imageURL.path) else {
            throw MediaStudioError.fileNotFound(imageURL)
        }
        guard FileManager.default.fileExists(atPath: logoURL.path) else {
            throw MediaStudioError.fileNotFound(logoURL)
        }
        guard let baseImage = NSImage(contentsOf: imageURL),
              let baseCG = baseImage.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let logoImage = NSImage(contentsOf: logoURL),
              let logoCG = logoImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw MediaStudioError.executionFailed("Unable to decode images")
        }
        
        let destFolder = destinationURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: destFolder, withIntermediateDirectories: true)
        let safeDestination = OutputNaming.uniqueDestinationURL(desiredURL: destinationURL)
        
        let width = baseCG.width
        let height = baseCG.height
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            throw MediaStudioError.executionFailed("Could not allocate graphics context")
        }
        
        context.draw(baseCG, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        let targetLogoWidth = CGFloat(width) * (scalePercent / 100.0)
        let aspectRatio = CGFloat(logoCG.height) / CGFloat(logoCG.width)
        let targetLogoHeight = targetLogoWidth * aspectRatio
        let padding: CGFloat = 24.0
        
        let logoRect: CGRect
        switch anchor {
        case .topLeft:
            logoRect = CGRect(x: padding, y: CGFloat(height) - targetLogoHeight - padding, width: targetLogoWidth, height: targetLogoHeight)
        case .topRight:
            logoRect = CGRect(x: CGFloat(width) - targetLogoWidth - padding, y: CGFloat(height) - targetLogoHeight - padding, width: targetLogoWidth, height: targetLogoHeight)
        case .bottomLeft:
            logoRect = CGRect(x: padding, y: padding, width: targetLogoWidth, height: targetLogoHeight)
        case .bottomRight:
            logoRect = CGRect(x: CGFloat(width) - targetLogoWidth - padding, y: padding, width: targetLogoWidth, height: targetLogoHeight)
        case .center:
            logoRect = CGRect(x: (CGFloat(width) - targetLogoWidth) / 2.0, y: (CGFloat(height) - targetLogoHeight) / 2.0, width: targetLogoWidth, height: targetLogoHeight)
        case .tile:
            logoRect = CGRect(x: padding, y: padding, width: targetLogoWidth, height: targetLogoHeight)
        }
        
        context.saveGState()
        context.setAlpha(opacity)
        context.draw(logoCG, in: logoRect)
        context.restoreGState()
        
        guard let outputCGImage = context.makeImage() else {
            throw MediaStudioError.executionFailed("Failed to make output image")
        }
        
        let outNSImage = NSImage(cgImage: outputCGImage, size: NSSize(width: width, height: height))
        guard let tiffData = outNSImage.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            throw MediaStudioError.executionFailed("Failed to encode PNG output")
        }
        
        try pngData.write(to: safeDestination, options: .atomic)
        return safeDestination
    }
    
    /// Applies a text watermark to a video file using native CoreGraphics text rendering + universal FFmpeg overlay.
    func applyTextWatermarkToVideo(
        videoURL: URL,
        text: String,
        anchor: WatermarkAnchor = .bottomRight,
        opacity: CGFloat = 0.7,
        fontSize: CGFloat = 24.0,
        destinationURL: URL
    ) async throws -> URL {
        guard let badgeURL = renderTextWatermarkImage(text: text, opacity: opacity, fontSize: fontSize) else {
            throw MediaStudioError.executionFailed("Failed to render watermark badge")
        }
        defer {
            try? FileManager.default.removeItem(at: badgeURL)
        }
        
        return try await applyImageWatermarkToVideo(
            videoURL: videoURL,
            logoURL: badgeURL,
            anchor: anchor,
            destinationURL: destinationURL
        )
    }
    
    /// Applies an image watermark badge to a video file using universal FFmpeg overlay.
    func applyImageWatermarkToVideo(
        videoURL: URL,
        logoURL: URL,
        anchor: WatermarkAnchor = .bottomRight,
        destinationURL: URL
    ) async throws -> URL {
        guard FileManager.default.fileExists(atPath: videoURL.path) else {
            throw MediaStudioError.fileNotFound(videoURL)
        }
        guard FileManager.default.fileExists(atPath: logoURL.path) else {
            throw MediaStudioError.fileNotFound(logoURL)
        }
        guard let ffmpegPath = FFmpegLocator.ffmpegPath else {
            throw MediaStudioError.executionFailed("ffmpeg binary not found")
        }
        
        let destFolder = destinationURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: destFolder, withIntermediateDirectories: true)
        let safeDestination = OutputNaming.uniqueDestinationURL(desiredURL: destinationURL)
        
        let overlayCoord: String
        switch anchor {
        case .topLeft:
            overlayCoord = "overlay=24:24"
        case .topRight:
            overlayCoord = "overlay=W-w-24:24"
        case .bottomLeft:
            overlayCoord = "overlay=24:H-h-24"
        case .bottomRight:
            overlayCoord = "overlay=W-w-24:H-h-24"
        case .center:
            overlayCoord = "overlay=(W-w)/2:(H-h)/2"
        case .tile:
            overlayCoord = "overlay=(W-w)/2:(H-h)/2"
        }
        
        let probe = MediaProbe.probe(url: videoURL)
        var arguments = [
            "-y",
            "-i", videoURL.path,
            "-i", logoURL.path,
            "-filter_complex", "[0:v][1:v]\(overlayCoord)[outv]",
            "-map", "[outv]",
            "-c:v", "libx264",
            "-preset", "veryfast",
            "-crf", "22"
        ]
        
        if probe?.hasAudio ?? false {
            arguments += ["-map", "0:a", "-c:a", "copy"]
        } else {
            arguments += ["-an"]
        }
        
        arguments.append(safeDestination.path)
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: ffmpegPath)
        process.arguments = arguments
        let errPipe = Pipe()
        process.standardError = errPipe
        
        try process.run()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0, FileManager.default.fileExists(atPath: safeDestination.path) else {
            let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
            let errStr = String(data: errData, encoding: .utf8) ?? ""
            throw MediaStudioError.executionFailed("Video watermarking failed: \(errStr.suffix(300))")
        }
        
        return safeDestination
    }
}
