import Foundation

struct ImagePreset: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var formatRawValue: String
    var quality: Double
    var keepOriginalFormat: Bool
    var targetSizeText: String
    var customFilenameText: String
    var resizeWidthText: String
    var preserveMetadata: Bool
}

struct VideoPreset: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var formatRawValue: String
    var keepOriginalContainer: Bool
    var targetSizeText: String
    var customFilenameText: String
    var resizeWidthText: String
    var preserveMetadata: Bool
}

struct AudioPreset: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var formatRawValue: String
    var quality: Double
    var keepOriginalFormat: Bool
    var targetSizeText: String
    var customFilenameText: String
    var preserveMetadata: Bool
}
