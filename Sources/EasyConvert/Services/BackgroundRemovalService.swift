import Foundation
import Vision
import CoreImage
import AppKit

enum BackgroundRemovalError: LocalizedError, Sendable {
    case imageLoadFailed(URL)
    case visionRequestFailed(String)
    case maskGenerationFailed
    case outputWriteFailed(URL)
    
    var errorDescription: String? {
        switch self {
        case .imageLoadFailed(let url):
            return "Failed to load image from \(url.lastPathComponent)."
        case .visionRequestFailed(let reason):
            return "Vision background removal failed: \(reason)"
        case .maskGenerationFailed:
            return "Unable to detect a distinct subject or foreground in the image."
        case .outputWriteFailed(let url):
            return "Failed to write transparent PNG to \(url.lastPathComponent)."
        }
    }
}

final class BackgroundRemovalService: Sendable {
    static let shared = BackgroundRemovalService()
    
    private let ciContext: CIContext
    
    init() {
        self.ciContext = CIContext(options: [.useSoftwareRenderer: false])
    }
    
    /// Removes background from an image file and exports a transparent PNG using Apple Vision on-device AI.
    func removeBackground(from sourceURL: URL, destinationURL: URL? = nil) async throws -> URL {
        guard let nsImage = NSImage(contentsOf: sourceURL),
              let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw BackgroundRemovalError.imageLoadFailed(sourceURL)
        }
        
        let outputCGImage = try await processForegroundMask(cgImage: cgImage)
        
        // Determine destination following zero-overwrite policy
        let outputDestination: URL
        if let destinationURL {
            outputDestination = destinationURL
        } else {
            let folder = sourceURL.deletingLastPathComponent()
            let baseName = sourceURL.deletingPathExtension().lastPathComponent
            let target = folder.appendingPathComponent("\(baseName)_nobg.png")
            outputDestination = OutputNaming.uniqueDestinationURL(desiredURL: target)
        }
        
        let destFolder = outputDestination.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: destFolder, withIntermediateDirectories: true)
        
        let bitmapRep = NSBitmapImageRep(cgImage: outputCGImage)
        guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            throw BackgroundRemovalError.outputWriteFailed(outputDestination)
        }
        
        try pngData.write(to: outputDestination, options: .atomic)
        return outputDestination
    }
    
    /// Processes a CGImage using Apple Vision VNGenerateForegroundInstanceMaskRequest or Person Segmentation.
    private func processForegroundMask(cgImage: CGImage) async throws -> CGImage {
        let width = cgImage.width
        let height = cgImage.height
        
        if #available(macOS 14.0, *) {
            let request = VNGenerateForegroundInstanceMaskRequest()
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            do {
                try handler.perform([request])
            } catch {
                throw BackgroundRemovalError.visionRequestFailed(error.localizedDescription)
            }
            
            if let result = request.results?.first {
                do {
                    // Generate full-res masked buffer containing all foreground instances
                    let allInstances = result.allInstances
                    let maskedPixelBuffer = try result.generateMaskedImage(
                        ofInstances: allInstances,
                        from: handler,
                        croppedToInstancesExtent: false
                    )
                    
                    let ciImage = CIImage(cvPixelBuffer: maskedPixelBuffer)
                    if let renderedCG = ciContext.createCGImage(ciImage, from: CGRect(x: 0, y: 0, width: width, height: height)) {
                        return renderedCG
                    }
                } catch {
                    // Fall back to manual alpha mask compositing if direct generation encountered error
                }
            }
        }
        
        // Fallback: Person Segmentation or CoreImage alpha masking
        return try await fallbackPersonSegmentation(cgImage: cgImage)
    }
    
    private func fallbackPersonSegmentation(cgImage: CGImage) async throws -> CGImage {
        let width = cgImage.width
        let height = cgImage.height
        
        let segRequest = VNGeneratePersonSegmentationRequest()
        segRequest.qualityLevel = .accurate
        segRequest.outputPixelFormat = kCVPixelFormatType_OneComponent8
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([segRequest])
        } catch {
            throw BackgroundRemovalError.visionRequestFailed(error.localizedDescription)
        }
        
        guard let maskResult = segRequest.results?.first else {
            throw BackgroundRemovalError.maskGenerationFailed
        }
        
        let maskPixelBuffer = maskResult.pixelBuffer
        let maskCIImage = CIImage(cvPixelBuffer: maskPixelBuffer)
        
        // Scale mask to source image dimensions
        let scaleX = CGFloat(width) / maskCIImage.extent.width
        let scaleY = CGFloat(height) / maskCIImage.extent.height
        let scaledMask = maskCIImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
        
        let inputCIImage = CIImage(cgImage: cgImage)
        let emptyBackground = CIImage(color: .clear).cropped(to: inputCIImage.extent)
        
        // Blend original image with transparent background using the segmentation mask
        guard let filter = CIFilter(name: "CIBlendWithMask") else {
            throw BackgroundRemovalError.maskGenerationFailed
        }
        filter.setValue(inputCIImage, forKey: kCIInputImageKey)
        filter.setValue(emptyBackground, forKey: kCIInputBackgroundImageKey)
        filter.setValue(scaledMask, forKey: kCIInputMaskImageKey)
        
        guard let outputCIImage = filter.outputImage,
              let finalCG = ciContext.createCGImage(outputCIImage, from: CGRect(x: 0, y: 0, width: width, height: height)) else {
            throw BackgroundRemovalError.maskGenerationFailed
        }
        
        return finalCG
    }
}
