import Foundation
import SwiftUI

// MARK: - Enums for App Settings

enum DestinationPolicy: String, CaseIterable, Identifiable {
    case sameAsSource = "Same folder as source"
    case customFolder = "Specified folder"
    case askEachTime = "Ask every time"
    
    var id: String { rawValue }
}

enum FileConflictAction: String, CaseIterable, Identifiable {
    case autoNumber = "Add number suffix (e.g. file_1)"
    case overwrite = "Overwrite existing"
    case prompt = "Ask what to do"
    
    var id: String { rawValue }
}

enum AppTheme: String, CaseIterable, Identifiable {
    case dark = "Dark"
    case light = "Light"
    case liquidGlass = "Liquid Glass"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .dark: return "moon.fill"
        case .light: return "sun.max.fill"
        case .liquidGlass: return "sparkles"
        }
    }
}

enum OutputNamingTemplate: String, CaseIterable, Identifiable {
    case standard = "Standard ({name}.{ext})"
    case suffixFormat = "Format Suffix ({name}_{format}.{ext})"
    case timestamp = "Timestamped ({name}_{date}.{ext})"
    case compressed = "Compressed Tag ({name}-compressed.{ext})"

    var id: String { rawValue }
}

// MARK: - Format Settings Structs

struct WebPConfig: Codable, Equatable {
    var isLossless: Bool = false
    var method: Int = 4 // 0...6
    var preset: String = "default" // default, photo, picture, drawing, icon, text
    var sharpYuv: Bool = true
    var filterStrength: Int = 0 // 0...100
}

struct JXLConfig: Codable, Equatable {
    var isLossless: Bool = false
    var effort: Int = 7 // 1...9
    var distance: Double = 1.0 // 0 = lossless
    var fasterDecoding: Int = 0 // 0...4
}

struct JPEGConfig: Codable, Equatable {
    var isProgressive: Bool = true
    var chromaSubsampling: String = "4:2:0" // 4:2:0, 4:2:2, 4:4:4
}

struct PNGConfig: Codable, Equatable {
    var compressionLevel: Int = 6 // 0...9
    var isInterlaced: Bool = false
}

struct TIFFConfig: Codable, Equatable {
    var compression: String = "LZW" // None, LZW, Deflate, PackBits
}

struct GIFConfig: Codable, Equatable {
    var maxColors: Int = 256 // 2...256
    var dither: Bool = true
}

struct VideoConfig: Codable, Equatable {
    var encodingMode: String = "crf" // "crf", "bitrate", "hardware"
    var crfValue: Int = 22 // 0...51 (lower is higher quality)
    var x264Preset: String = "medium" // ultrafast, superfast, veryfast, faster, fast, medium, slow, slower, veryslow
    var x264Tune: String = "none" // none, film, animation, grain, stillimage, fastdecode, zerolatency
    var pixelFormat: String = "yuv420p" // yuv420p, yuv422p, yuv444p, yuv420p10le
    var deinterlace: Bool = false
    var frameRate: String = "keep" // keep, 24, 25, 29.97, 30, 50, 60
    var scalingAlgorithm: String = "lanczos" // lanczos, bicubic, bilinear
    var audioCodec: String = "auto" // auto, aac, mp3, opus, ac3, copy, none
    var audioBitrateKbps: Int = 192
    var preferHardwareAcceleration: Bool = true
}

struct AudioConfig: Codable, Equatable {
    var bitrateMode: String = "cbr" // cbr, vbr, abr
    var cbrBitrateKbps: Int = 192 // 32...320
    var vbrQuality: Int = 2 // 0...9 (0 is highest quality)
    var sampleRateHz: String = "keep" // keep, 44100, 48000, 88200, 96000, 192000
    var channels: String = "keep" // keep, mono, stereo, downmix51
    var losslessBitDepth: String = "16" // 16, 24, 32
    var flacCompressionLevel: Int = 5 // 0...8
    var opusApplication: String = "audio" // audio, voip, lowdelay
    var normalizeEBUR128: Bool = false
}

// MARK: - AppSettings Store

@Observable
final class AppSettings {
    static let shared = AppSettings()
    
    // MARK: - General Settings
    var destinationPolicy: DestinationPolicy {
        didSet { UserDefaults.standard.set(destinationPolicy.rawValue, forKey: "destinationPolicy") }
    }
    
    var customDestinationPath: String {
        didSet { UserDefaults.standard.set(customDestinationPath, forKey: "customDestinationPath") }
    }
    
    var fileConflictAction: FileConflictAction {
        didSet { UserDefaults.standard.set(fileConflictAction.rawValue, forKey: "fileConflictAction") }
    }
    
    var maxConcurrentJobs: Int {
        didSet { UserDefaults.standard.set(maxConcurrentJobs, forKey: "maxConcurrentJobs") }
    }
    
    var notifyOnComplete: Bool {
        didSet { UserDefaults.standard.set(notifyOnComplete, forKey: "notifyOnComplete") }
    }
    
    var playCompletionSound: Bool {
        didSet { UserDefaults.standard.set(playCompletionSound, forKey: "playCompletionSound") }
    }
    
    var autoRevealInFinder: Bool {
        didSet { UserDefaults.standard.set(autoRevealInFinder, forKey: "autoRevealInFinder") }
    }
    
    var deleteSourceAfterConversion: Bool {
        didSet { UserDefaults.standard.set(deleteSourceAfterConversion, forKey: "deleteSourceAfterConversion") }
    }

    var showMenuBarDropzone: Bool {
        didSet { UserDefaults.standard.set(showMenuBarDropzone, forKey: "showMenuBarDropzone") }
    }

    var namingTemplate: OutputNamingTemplate {
        didSet { UserDefaults.standard.set(namingTemplate.rawValue, forKey: "namingTemplate") }
    }

    var appTheme: AppTheme {
        didSet { UserDefaults.standard.set(appTheme.rawValue, forKey: "appTheme") }
    }
    
    var maxFileSizeBytes: Int64? {
        didSet {
            if let maxFileSizeBytes {
                UserDefaults.standard.set(maxFileSizeBytes, forKey: "maxFileSizeBytes")
            } else {
                UserDefaults.standard.set(-1, forKey: "maxFileSizeBytes")
            }
        }
    }
    
    // MARK: - Format Specific Settings
    var webpConfig: WebPConfig {
        didSet { saveJSON(webpConfig, forKey: "webpConfig") }
    }
    var jxlConfig: JXLConfig {
        didSet { saveJSON(jxlConfig, forKey: "jxlConfig") }
    }
    var jpegConfig: JPEGConfig {
        didSet { saveJSON(jpegConfig, forKey: "jpegConfig") }
    }
    var pngConfig: PNGConfig {
        didSet { saveJSON(pngConfig, forKey: "pngConfig") }
    }
    var tiffConfig: TIFFConfig {
        didSet { saveJSON(tiffConfig, forKey: "tiffConfig") }
    }
    var gifConfig: GIFConfig {
        didSet { saveJSON(gifConfig, forKey: "gifConfig") }
    }
    var videoConfig: VideoConfig {
        didSet { saveJSON(videoConfig, forKey: "videoConfig") }
    }
    var audioConfig: AudioConfig {
        didSet { saveJSON(audioConfig, forKey: "audioConfig") }
    }
    
    // MARK: - Initializer
    private init() {
        let defaults = UserDefaults.standard
        
        let destRaw = defaults.string(forKey: "destinationPolicy") ?? DestinationPolicy.sameAsSource.rawValue
        self.destinationPolicy = DestinationPolicy(rawValue: destRaw) ?? .sameAsSource
        
        self.customDestinationPath = defaults.string(forKey: "customDestinationPath") ?? ""
        
        let conflictRaw = defaults.string(forKey: "fileConflictAction") ?? FileConflictAction.autoNumber.rawValue
        self.fileConflictAction = FileConflictAction(rawValue: conflictRaw) ?? .autoNumber
        
        let defaultConcurrency = max(1, min(4, ProcessInfo.processInfo.activeProcessorCount))
        self.maxConcurrentJobs = defaults.object(forKey: "maxConcurrentJobs") as? Int ?? defaultConcurrency
        
        self.notifyOnComplete = defaults.object(forKey: "notifyOnComplete") as? Bool ?? true
        self.playCompletionSound = defaults.object(forKey: "playCompletionSound") as? Bool ?? true
        self.autoRevealInFinder = defaults.object(forKey: "autoRevealInFinder") as? Bool ?? false
        self.deleteSourceAfterConversion = defaults.object(forKey: "deleteSourceAfterConversion") as? Bool ?? false
        self.showMenuBarDropzone = defaults.object(forKey: "showMenuBarDropzone") as? Bool ?? false

        let templateRaw = defaults.string(forKey: "namingTemplate") ?? OutputNamingTemplate.standard.rawValue
        self.namingTemplate = OutputNamingTemplate(rawValue: templateRaw) ?? .standard

        let themeRaw = defaults.string(forKey: "appTheme") ?? AppTheme.dark.rawValue
        self.appTheme = AppTheme(rawValue: themeRaw) ?? .dark
        
        if let stored = defaults.object(forKey: "maxFileSizeBytes") as? NSNumber {
            let val = stored.int64Value
            self.maxFileSizeBytes = val < 0 ? nil : val
        } else {
            self.maxFileSizeBytes = 4_000_000_000
        }
        
        self.webpConfig = Self.loadJSON(forKey: "webpConfig") ?? WebPConfig()
        self.jxlConfig = Self.loadJSON(forKey: "jxlConfig") ?? JXLConfig()
        self.jpegConfig = Self.loadJSON(forKey: "jpegConfig") ?? JPEGConfig()
        self.pngConfig = Self.loadJSON(forKey: "pngConfig") ?? PNGConfig()
        self.tiffConfig = Self.loadJSON(forKey: "tiffConfig") ?? TIFFConfig()
        self.gifConfig = Self.loadJSON(forKey: "gifConfig") ?? GIFConfig()
        self.videoConfig = Self.loadJSON(forKey: "videoConfig") ?? VideoConfig()
        self.audioConfig = Self.loadJSON(forKey: "audioConfig") ?? AudioConfig()
    }
    
    // MARK: - Helpers
    private func saveJSON<T: Encodable>(_ value: T, forKey key: String) {
        if let data = try? JSONEncoder().encode(value) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
    
    private static func loadJSON<T: Decodable>(forKey key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
    
    static let sizePresets: [(label: String, bytes: Int64?)] = [
        ("500 MB", 500_000_000),
        ("1 GB", 1_000_000_000),
        ("4 GB", 4_000_000_000),
        ("16 GB", 16_000_000_000),
        ("No limit", nil)
    ]
}

enum FeasibilityChecker {
    private static let formatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter
    }()

    /// Returns a human-readable warning if `url` exceeds the configured size limit, else `nil`.
    static func checkFileSize(_ url: URL) -> String? {
        guard let limit = AppSettings.shared.maxFileSizeBytes else { return nil }
        guard let size = try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64 else { return nil }
        guard size > limit else { return nil }
        return "File is \(formatter.string(fromByteCount: size)), which exceeds the \(formatter.string(fromByteCount: limit)) limit."
    }
}
