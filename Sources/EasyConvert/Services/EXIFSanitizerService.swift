import Foundation
import CoreGraphics
import ImageIO
import AppKit

struct ImageMetadataReport: Sendable {
    let hasGPS: Bool
    let gpsLatitude: Double?
    let gpsLongitude: Double?
    let cameraMake: String?
    let cameraModel: String?
    let lensModel: String?
    let dateTimeOriginal: String?
    let software: String?
    let rawPropertyCount: Int
}

final class EXIFSanitizerService: Sendable {
    static let shared = EXIFSanitizerService()
    
    init() {}
    
    /// Reads and parses all privacy-sensitive metadata (GPS coordinates, camera serials, timestamps) from an image.
    func readMetadata(imageURL: URL) async throws -> ImageMetadataReport {
        guard FileManager.default.fileExists(atPath: imageURL.path) else {
            throw MediaStudioError.fileNotFound(imageURL)
        }
        guard let source = CGImageSourceCreateWithURL(imageURL as CFURL, nil) else {
            throw MediaStudioError.executionFailed("Unable to read image metadata")
        }
        
        let properties = (CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]) ?? [:]
        
        let gpsDict = properties[kCGImagePropertyGPSDictionary] as? [CFString: Any]
        let exifDict = properties[kCGImagePropertyExifDictionary] as? [CFString: Any]
        let tiffDict = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any]
        
        let hasGPS = gpsDict != nil && !(gpsDict?.isEmpty ?? true)
        let lat = gpsDict?[kCGImagePropertyGPSLatitude] as? Double
        let lon = gpsDict?[kCGImagePropertyGPSLongitude] as? Double
        
        let make = tiffDict?[kCGImagePropertyTIFFMake] as? String
        let model = tiffDict?[kCGImagePropertyTIFFModel] as? String
        let lens = exifDict?[kCGImagePropertyExifLensModel] as? String
        let date = (exifDict?[kCGImagePropertyExifDateTimeOriginal] as? String) ?? (tiffDict?[kCGImagePropertyTIFFDateTime] as? String)
        let software = tiffDict?[kCGImagePropertyTIFFSoftware] as? String
        
        return ImageMetadataReport(
            hasGPS: hasGPS,
            gpsLatitude: lat,
            gpsLongitude: lon,
            cameraMake: make,
            cameraModel: model,
            lensModel: lens,
            dateTimeOriginal: date,
            software: software,
            rawPropertyCount: properties.count
        )
    }
    
    /// Strips all privacy-sensitive EXIF, GPS, IPTC, and TIFF metadata from an image,
    /// creating a clean image file with identical pixel content.
    func stripMetadata(
        sourceURL: URL,
        destinationURL: URL
    ) async throws -> URL {
        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            throw MediaStudioError.fileNotFound(sourceURL)
        }
        guard let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil),
              let type = CGImageSourceGetType(source) else {
            throw MediaStudioError.executionFailed("Failed to read image for metadata stripping")
        }
        
        let destFolder = destinationURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: destFolder, withIntermediateDirectories: true)
        let safeDestination = OutputNaming.uniqueDestinationURL(desiredURL: destinationURL)
        
        guard let destination = CGImageDestinationCreateWithURL(safeDestination as CFURL, type, 1, nil) else {
            throw MediaStudioError.executionFailed("Failed to create image destination")
        }
        
        // Pass empty properties dictionary to strip all metadata tags
        let emptyProperties: [CFString: Any] = [:]
        CGImageDestinationAddImage(destination, cgImage, emptyProperties as CFDictionary)
        
        guard CGImageDestinationFinalize(destination) else {
            throw MediaStudioError.executionFailed("Failed to finalize sanitized image")
        }
        
        return safeDestination
    }
}
