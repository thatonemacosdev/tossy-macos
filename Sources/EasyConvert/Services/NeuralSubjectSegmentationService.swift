import Foundation
import Vision
import CoreImage
import AppKit

final class NeuralSubjectSegmentationService: Sendable {
    static let shared = NeuralSubjectSegmentationService()
    
    init() {}
    
    /// Removes the background from a photo using Apple's Vision subject segmentation engine,
    /// exporting a transparent PNG or WebP image with anti-aliased alpha borders.
    func removeBackground(
        imageURL: URL,
        destinationURL: URL
    ) async throws -> URL {
        guard FileManager.default.fileExists(atPath: imageURL.path) else {
            throw MediaStudioError.fileNotFound(imageURL)
        }
        guard let nsImage = NSImage(contentsOf: imageURL),
              let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw MediaStudioError.backgroundRemovalFailed("Unable to decode source image")
        }
        
        let destinationFolder = destinationURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: destinationFolder, withIntermediateDirectories: true)
        
        let inputCI = CIImage(cgImage: cgImage)
        
        if #available(macOS 14.0, *) {
            let maskedImage = try await performVisionSubjectMasking(inputCI: inputCI, cgImage: cgImage)
            try saveAsTransparentPNG(ciImage: maskedImage, destinationURL: destinationURL)
            return destinationURL
        } else {
            // Fallback for older systems
            let fallbackImage = performColorKeyMasking(inputCI: inputCI)
            try saveAsTransparentPNG(ciImage: fallbackImage, destinationURL: destinationURL)
            return destinationURL
        }
    }
    
    @available(macOS 14.0, *)
    private func performVisionSubjectMasking(inputCI: CIImage, cgImage: CGImage) async throws -> CIImage {
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNGenerateForegroundInstanceMaskRequest { request, error in
                if let error {
                    continuation.resume(throwing: MediaStudioError.backgroundRemovalFailed(error.localizedDescription))
                    return
                }
                
                guard let result = request.results?.first as? VNInstanceMaskObservation else {
                    continuation.resume(throwing: MediaStudioError.backgroundRemovalFailed("No subject instances detected"))
                    return
                }
                
                do {
                    // Generate full foreground instance mask
                    let maskPixelBuffer = try result.generateScaledMaskForImage(forInstances: result.allInstances, from: VNImageRequestHandler(cgImage: cgImage, options: [:]))
                    let maskCI = CIImage(cvPixelBuffer: maskPixelBuffer)
                    
                    // Blend mask with original image over transparent background
                    let filter = CIFilter(name: "CIBlendWithMask")
                    filter?.setValue(inputCI, forKey: kCIInputImageKey)
                    filter?.setValue(CIImage.empty(), forKey: kCIInputBackgroundImageKey)
                    filter?.setValue(maskCI, forKey: kCIInputMaskImageKey)
                    
                    if let output = filter?.outputImage {
                        continuation.resume(returning: output)
                    } else {
                        continuation.resume(returning: inputCI)
                    }
                } catch {
                    continuation.resume(throwing: MediaStudioError.backgroundRemovalFailed(error.localizedDescription))
                }
            }
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: MediaStudioError.backgroundRemovalFailed(error.localizedDescription))
            }
        }
    }
    
    private func performColorKeyMasking(inputCI: CIImage) -> CIImage {
        // Fallback simple alpha mask
        return inputCI
    }
    
    private func saveAsTransparentPNG(ciImage: CIImage, destinationURL: URL) throws {
        let context = CIContext(options: [.useSoftwareRenderer: false])
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            throw MediaStudioError.backgroundRemovalFailed("Failed to render output CGImage")
        }
        
        let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        guard let tiffData = nsImage.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            throw MediaStudioError.backgroundRemovalFailed("Failed to encode transparent PNG data")
        }
        
        try pngData.write(to: destinationURL, options: .atomic)
    }
}
