import Foundation
import ImageIO
import CoreImage
import Metal
import UniformTypeIdentifiers

enum ConversionError: LocalizedError {
    case unreadableImage
    case destinationCreationFailed
    case renderFailed
    case writeFailed
    case formatUnavailable(String)

    var errorDescription: String? {
        switch self {
        case .unreadableImage: return "Couldn't read this file as an image."
        case .destinationCreationFailed: return "Couldn't create the output file."
        case .renderFailed: return "The GPU render pipeline failed to produce an image."
        case .writeFailed: return "Couldn't write the converted image to disk."
        case .formatUnavailable(let reason): return reason
        }
    }
}

struct ImageConversionResult {
    let outputURLs: [URL]
    /// Set when a target size was requested  -  reports whether it was hit and the final size.
    let note: String?
}

/// Converts images using ImageIO (the same system-standard decode/encode engine behind
/// `sips`, Preview, and Quick Look) with the pixel pipeline routed through a Metal-backed
/// Core Image context, so color management and resampling run on the GPU rather than the CPU.
/// RAW camera files and vector/document sources (SVG/PDF/EPS/AI) are decoded first via
/// dedicated helpers; formats ImageIO can't write (WebP, HDR, QOI, ...) fall back to the
/// bundled ffmpeg or WebP tools.
final class ImageConverter {
    private let ciContext: CIContext
    let isGPUAccelerated: Bool

    /// Pass `forceSoftwareRenderer: true` to force the CPU rendering path  -  useful only for
    /// benchmarking the Metal-backed path against a software baseline.
    init(forceSoftwareRenderer: Bool = false) {
        if !forceSoftwareRenderer, let device = MTLCreateSystemDefaultDevice() {
            ciContext = CIContext(mtlDevice: device)
            isGPUAccelerated = true
        } else {
            ciContext = CIContext(options: [.useSoftwareRenderer: true])
            isGPUAccelerated = false
        }
    }

    /// Converts `sourceURL` to `format`, writing into `destinationFolder` (or alongside the
    /// source if `nil`). Returns one URL per page for multi-page PDF sources, one URL otherwise.
    /// When `targetSizeBytes` is set, each page is compressed (quality search for lossy formats,
    /// resolution search for lossless ones) to fit under that size, best-effort.
    func convert(
        sourceURL: URL,
        to format: ImageFormat,
        quality: Double = 0.85,
        destinationFolder: URL? = nil,
        targetSizeBytes: Int64? = nil,
        targetWidth: Int? = nil,
        customBaseName: String? = nil,
        preserveMetadata: Bool = true
    ) async throws -> ImageConversionResult {
        guard format.isAvailable else {
            throw ConversionError.formatUnavailable(format.unavailabilityReason ?? "This format isn't available.")
        }

        var metadataDict: [CFString: Any]? = nil
        if preserveMetadata,
           let imageSource = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
           let sourceProps = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any] {
            var extracted: [CFString: Any] = [:]
            if let exif = sourceProps[kCGImagePropertyExifDictionary] {
                extracted[kCGImagePropertyExifDictionary] = exif
            }
            if let gps = sourceProps[kCGImagePropertyGPSDictionary] {
                extracted[kCGImagePropertyGPSDictionary] = gps
            }
            if let tiff = sourceProps[kCGImagePropertyTIFFDictionary] {
                extracted[kCGImagePropertyTIFFDictionary] = tiff
            }
            if !extracted.isEmpty {
                metadataDict = extracted
            }
        }

        let sourceImages = try decodeSourceImages(sourceURL: sourceURL)
        var outputs: [URL] = []
        var notes: [String] = []

        for (index, cgImage) in sourceImages.enumerated() {
            var ciImage = CIImage(cgImage: cgImage)

            // Explicit resize request  -  applied before any other pipeline step, aspect-preserving.
            if let targetWidth, targetWidth > 0, ciImage.extent.width > 0 {
                let scale = CGFloat(targetWidth) / ciImage.extent.width
                if abs(scale - 1) > 0.001 {
                    ciImage = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
                }
            }

            // ICO caps out at 256×256; downscale rather than let the writer silently fail.
            if format == .ico {
                let maxDimension: CGFloat = 256
                let scale = min(1, maxDimension / max(ciImage.extent.width, ciImage.extent.height))
                if scale < 1 {
                    ciImage = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
                }
            }

            // ICNS only accepts specific square sizes (16/32/64/128/256/512/1024)  -  anything
            // else fails to finalize. Snap to the nearest one, square-cropping first if needed.
            if format == .icns {
                let standardSizes: [CGFloat] = [16, 32, 64, 128, 256, 512, 1024]
                let side = min(ciImage.extent.width, ciImage.extent.height)
                if side > 0 {
                    let squareExtent = CGRect(x: ciImage.extent.minX, y: ciImage.extent.minY, width: side, height: side)
                    ciImage = ciImage.cropped(to: squareExtent)
                    let nearest = standardSizes.min(by: { abs($0 - side) < abs($1 - side) }) ?? 512
                    let scale = nearest / side
                    if abs(scale - 1) > 0.001 {
                        ciImage = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
                    }
                }
            }

            let pageSuffix = sourceImages.count > 1 ? "-page\(index + 1)" : ""
            let outputURL = OutputNaming.uniqueOutputURL(
                for: sourceURL,
                fileExtension: format.fileExtension,
                destinationFolder: destinationFolder,
                nameSuffix: pageSuffix,
                baseNameOverride: customBaseName
            )

            if let targetSizeBytes {
                let (size, met) = try await fitToTargetSize(
                    ciImage: ciImage,
                    format: format,
                    initialQuality: quality,
                    outputURL: outputURL,
                    targetSizeBytes: targetSizeBytes,
                    metadataDict: metadataDict
                )
                let sizeText = ByteSize.displayString(size)
                let targetText = ByteSize.displayString(targetSizeBytes)
                notes.append(met ? "Hit target: \(sizeText) (≤ \(targetText))" : "Couldn't reach \(targetText); smallest achievable was \(sizeText)")
            } else {
                guard let renderedImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else {
                    throw ConversionError.renderFailed
                }
                try await write(cgImage: renderedImage, to: outputURL, format: format, quality: quality, metadataDict: metadataDict)
            }

            outputs.append(outputURL)
        }

        return ImageConversionResult(outputURLs: outputs, note: notes.first)
    }

    // MARK: - Target size fitting

    private func fitToTargetSize(
        ciImage: CIImage,
        format: ImageFormat,
        initialQuality: Double,
        outputURL: URL,
        targetSizeBytes: Int64,
        metadataDict: [CFString: Any]? = nil
    ) async throws -> (size: Int64, met: Bool) {
        if format.supportsQuality {
            return try await binarySearch(
                low: 0.02, high: max(initialQuality, 0.05),
                targetSizeBytes: targetSizeBytes, outputURL: outputURL
            ) { candidateQuality, candidateURL in
                guard let cgImage = self.ciContext.createCGImage(ciImage, from: ciImage.extent) else {
                    throw ConversionError.renderFailed
                }
                try await self.write(cgImage: cgImage, to: candidateURL, format: format, quality: candidateQuality, metadataDict: metadataDict)
            }
        } else {
            return try await binarySearch(
                low: 0.05, high: 1.0,
                targetSizeBytes: targetSizeBytes, outputURL: outputURL
            ) { candidateScale, candidateURL in
                let scaled = candidateScale < 1.0 ? ciImage.transformed(by: CGAffineTransform(scaleX: candidateScale, y: candidateScale)) : ciImage
                guard let cgImage = self.ciContext.createCGImage(scaled, from: scaled.extent) else {
                    throw ConversionError.renderFailed
                }
                try await self.write(cgImage: cgImage, to: candidateURL, format: format, quality: 1.0, metadataDict: metadataDict)
            }
        }
    }

    /// Binary-searches `parameter` in `low...high` (quality or resolution scale  -  higher is
    /// "bigger file") for the largest value whose output still fits under `targetSizeBytes`.
    /// Writes the winning attempt to `outputURL` and reports whether the target was actually met.
    private func binarySearch(
        low: Double,
        high: Double,
        targetSizeBytes: Int64,
        outputURL: URL,
        attempts: Int = 7,
        write: (Double, URL) async throws -> Void
    ) async throws -> (size: Int64, met: Bool) {
        var lo = low
        var hi = high
        var best: (url: URL, size: Int64, parameter: Double)?

        for _ in 0..<attempts {
            let mid = (lo + hi) / 2
            let candidateURL = temporaryFileURL(matching: outputURL)
            do {
                try await write(mid, candidateURL)
            } catch {
                // Don't leave a half-finished attempt, or an already-found best-so-far, behind
                // in the temp directory just because a later candidate failed to write.
                try? FileManager.default.removeItem(at: candidateURL)
                if let best { try? FileManager.default.removeItem(at: best.url) }
                throw error
            }
            let size = fileSize(candidateURL)

            if size <= targetSizeBytes {
                if let existingBest = best {
                    try? FileManager.default.removeItem(at: existingBest.url)
                }
                best = (candidateURL, size, mid)
                lo = mid
            } else {
                try? FileManager.default.removeItem(at: candidateURL)
                hi = mid
            }
        }

        if let best {
            if FileManager.default.fileExists(atPath: outputURL.path) {
                try? FileManager.default.removeItem(at: outputURL)
            }
            try FileManager.default.moveItem(at: best.url, to: outputURL)
            return (best.size, true)
        }

        // Never fit even at the floor of the search range  -  write that floor attempt anyway
        // so the user still gets a (smallest-achievable) result rather than nothing.
        let fallbackURL = temporaryFileURL(matching: outputURL)
        try await write(lo, fallbackURL)
        let size = fileSize(fallbackURL)
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try? FileManager.default.removeItem(at: outputURL)
        }
        try FileManager.default.moveItem(at: fallbackURL, to: outputURL)
        return (size, false)
    }

    private func temporaryFileURL(matching outputURL: URL) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(outputURL.pathExtension)
    }

    private func fileSize(_ url: URL) -> Int64 {
        (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
    }

    private func decodeSourceImages(sourceURL: URL) throws -> [CGImage] {
        if let rawCIImage = RawImageDecoder.decode(url: sourceURL) {
            guard let cgImage = ciContext.createCGImage(rawCIImage, from: rawCIImage.extent) else {
                throw ConversionError.renderFailed
            }
            return [cgImage]
        }

        if VectorImageRenderer.isVectorOrDocumentSource(at: sourceURL) {
            return try VectorImageRenderer.render(url: sourceURL)
        }

        guard let imageSource = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            throw ConversionError.unreadableImage
        }
        return [cgImage]
    }

    private func write(cgImage: CGImage, to outputURL: URL, format: ImageFormat, quality: Double, metadataDict: [CFString: Any]? = nil) async throws {
        switch format.backend {
        case .imageIO:
            try writeViaImageIO(cgImage: cgImage, to: outputURL, format: format, quality: quality, metadataDict: metadataDict)
        case .webpTool:
            try await writeViaWebPTool(cgImage: cgImage, to: outputURL, quality: quality)
        case .jxlTool:
            try await writeViaJXLTool(cgImage: cgImage, to: outputURL, quality: quality)
        case .ffmpeg(let codec):
            try await writeViaFFmpeg(cgImage: cgImage, to: outputURL, codec: codec, format: format, quality: quality)
        }
    }

    private func writeViaImageIO(cgImage: CGImage, to outputURL: URL, format: ImageFormat, quality: Double, metadataDict: [CFString: Any]? = nil) throws {
        guard let destination = CGImageDestinationCreateWithURL(
            outputURL as CFURL,
            format.utType.identifier as CFString,
            1,
            nil
        ) else {
            throw ConversionError.destinationCreationFailed
        }

        var properties: [CFString: Any] = [:]
        if format.supportsQuality {
            properties[kCGImageDestinationLossyCompressionQuality] = quality
        }

        // Apply format-specific CLI / settings configurations
        if format == .jpeg {
            let jpegCfg = AppSettings.shared.jpegConfig
            var jfifDict: [CFString: Any] = [:]
            if jpegCfg.isProgressive {
                jfifDict[kCGImagePropertyJFIFIsProgressive] = kCFBooleanTrue
            }
            if !jfifDict.isEmpty {
                properties[kCGImagePropertyJFIFDictionary] = jfifDict
            }
        } else if format == .png {
            let pngCfg = AppSettings.shared.pngConfig
            var pngDict: [CFString: Any] = [:]
            if pngCfg.isInterlaced {
                pngDict[kCGImagePropertyPNGInterlaceType] = 1
            }
            if !pngDict.isEmpty {
                properties[kCGImagePropertyPNGDictionary] = pngDict
            }
        } else if format == .tiff {
            let tiffCfg = AppSettings.shared.tiffConfig
            let compressionValue: Int
            switch tiffCfg.compression.lowercased() {
            case "none": compressionValue = 1
            case "lzw": compressionValue = 5
            case "deflate", "zip": compressionValue = 8
            case "packbits": compressionValue = 32773
            default: compressionValue = 5
            }
            var tiffDict = (metadataDict?[kCGImagePropertyTIFFDictionary] as? [CFString: Any]) ?? [:]
            tiffDict[kCGImagePropertyTIFFCompression] = compressionValue
            properties[kCGImagePropertyTIFFDictionary] = tiffDict
        }

        if let metadataDict {
            for (key, value) in metadataDict {
                if properties[key] == nil {
                    properties[key] = value
                }
            }
        }

        CGImageDestinationAddImage(destination, cgImage, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw ConversionError.writeFailed
        }
        // Some writers (e.g. DDS on this platform) report success but emit a 0-byte file.
        let size = (try? FileManager.default.attributesOfItem(atPath: outputURL.path)[.size] as? Int) ?? 0
        guard size > 0 else {
            try? FileManager.default.removeItem(at: outputURL)
            throw ConversionError.writeFailed
        }
    }

    private func writeViaJXLTool(cgImage: CGImage, to outputURL: URL, quality: Double) async throws {
        guard let cjxlPath = JXLLocator.cjxlPath else {
            throw ConversionError.formatUnavailable("The bundled JPEG XL encoder (cjxl) wasn't found.")
        }
        let tempPNG = try writeTemporaryPNG(cgImage: cgImage)
        defer { try? FileManager.default.removeItem(at: tempPNG) }

        let jxlCfg = AppSettings.shared.jxlConfig
        var arguments = [tempPNG.path, outputURL.path, "--quiet"]
        if jxlCfg.isLossless {
            arguments += ["--distance", "0"]
        } else {
            let distance = max(0.1, (1.0 - quality) * 15.0)
            arguments += ["--distance", String(format: "%.2f", distance)]
        }
        arguments += ["-e", "\(jxlCfg.effort)"]
        if jxlCfg.fasterDecoding > 0 {
            arguments += ["--faster_decoding", "\(jxlCfg.fasterDecoding)"]
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: cjxlPath)
        process.arguments = arguments
        let errorPipe = Pipe()
        process.standardError = errorPipe
        process.standardOutput = FileHandle.nullDevice

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            process.terminationHandler = { proc in
                if proc.terminationStatus == 0 {
                    continuation.resume()
                } else {
                    let data = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    let message = String(data: data, encoding: .utf8) ?? "cjxl failed."
                    continuation.resume(throwing: ConversionError.formatUnavailable(message))
                }
            }
            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private func writeViaWebPTool(cgImage: CGImage, to outputURL: URL, quality: Double) async throws {
        guard let cwebpPath = WebPLocator.cwebpPath else {
            throw ConversionError.formatUnavailable("The bundled WebP encoder (cwebp) wasn't found.")
        }
        let tempPNG = try writeTemporaryPNG(cgImage: cgImage)
        defer { try? FileManager.default.removeItem(at: tempPNG) }

        let webpCfg = AppSettings.shared.webpConfig
        var arguments = ["-quiet"]
        if webpCfg.isLossless {
            arguments += ["-lossless"]
        } else {
            let qualityArg = String(Int(quality * 100))
            arguments += ["-q", qualityArg]
        }
        arguments += ["-m", "\(webpCfg.method)"]
        if webpCfg.preset != "default" {
            arguments += ["-preset", webpCfg.preset]
        }
        if webpCfg.sharpYuv {
            arguments += ["-sharp_yuv"]
        }
        if webpCfg.filterStrength > 0 {
            arguments += ["-sns", "\(webpCfg.filterStrength)"]
        }
        arguments += [tempPNG.path, "-o", outputURL.path]

        let process = Process()
        process.executableURL = URL(fileURLWithPath: cwebpPath)
        process.arguments = arguments
        let errorPipe = Pipe()
        process.standardError = errorPipe
        process.standardOutput = FileHandle.nullDevice

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            process.terminationHandler = { proc in
                if proc.terminationStatus == 0 {
                    continuation.resume()
                } else {
                    let data = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    let message = String(data: data, encoding: .utf8) ?? "cwebp failed."
                    continuation.resume(throwing: ConversionError.formatUnavailable(message))
                }
            }
            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private func writeViaFFmpeg(cgImage: CGImage, to outputURL: URL, codec: String, format: ImageFormat, quality: Double) async throws {
        let tempPNG = try writeTemporaryPNG(cgImage: cgImage)
        defer { try? FileManager.default.removeItem(at: tempPNG) }

        var arguments = ["-y", "-i", tempPNG.path, "-c:v", codec]
        if format.supportsQuality {
            // Map 0...1 to ffmpeg's coarser -q:v scale (2 = best, 31 = worst) for still-image codecs.
            let q = Int((1 - quality) * 29) + 2
            arguments += ["-q:v", String(q)]
        }
        arguments.append(outputURL.path)

        try await FFmpegService().run(arguments: arguments, totalDuration: nil) { _ in }
    }

    private func writeTemporaryPNG(cgImage: CGImage) throws -> URL {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("png")
        guard let destination = CGImageDestinationCreateWithURL(tempURL as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw ConversionError.destinationCreationFailed
        }
        CGImageDestinationAddImage(destination, cgImage, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw ConversionError.writeFailed
        }
        return tempURL
    }
}
