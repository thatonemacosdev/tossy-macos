import Foundation

struct ImagePreset: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String
    var formatRawValue: String
    var quality: Double
    var keepOriginalFormat: Bool
    var targetSizeText: String
    var customFilenameText: String
    var resizeWidthText: String
    var preserveMetadata: Bool
    
    // Detailed CLI configs (optional with default fallbacks for migration)
    var webpConfig: WebPConfig? = nil
    var jxlConfig: JXLConfig? = nil
    var jpegConfig: JPEGConfig? = nil
    var pngConfig: PNGConfig? = nil
    var tiffConfig: TIFFConfig? = nil
    var gifConfig: GIFConfig? = nil
}

struct VideoPreset: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String
    var formatRawValue: String
    var keepOriginalContainer: Bool
    var targetSizeText: String
    var customFilenameText: String
    var resizeWidthText: String
    var preserveMetadata: Bool
    
    // Detailed CLI config
    var videoConfig: VideoConfig? = nil
}

struct AudioPreset: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String
    var formatRawValue: String
    var quality: Double
    var keepOriginalFormat: Bool
    var targetSizeText: String
    var customFilenameText: String
    var preserveMetadata: Bool
    
    // Detailed CLI config
    var audioConfig: AudioConfig? = nil
}
