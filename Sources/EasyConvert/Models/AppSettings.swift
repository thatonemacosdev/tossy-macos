import Foundation
import SwiftUI
import ServiceManagement

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
    // Dark Themes
    case dark = "Dark"
    case midnightCobalt = "Midnight Cobalt"
    case emerald = "Emerald Matrix"
    case solarAmber = "Solar Amber"
    case hyperViolet = "Neon Violet"
    case titanium = "Titanium"
    case liquidGlass = "Liquid Glass"

    // Light Themes
    case light = "Light"
    case rose = "Rose"
    case cream = "Cream"
    case sage = "Sage"

    var id: String { rawValue }

    var isDark: Bool {
        switch self {
        case .dark, .midnightCobalt, .emerald, .solarAmber, .hyperViolet, .titanium, .liquidGlass:
            return true
        case .light, .rose, .cream, .sage:
            return false
        }
    }

    var isLight: Bool { !isDark }

    static var darkThemes: [AppTheme] {
        [.dark, .midnightCobalt, .emerald, .solarAmber, .hyperViolet, .titanium, .liquidGlass]
    }

    static var lightThemes: [AppTheme] {
        [.light, .rose, .cream, .sage]
    }

    var displayName: String {
        switch self {
        case .dark: return "Monochrome Black"
        case .midnightCobalt: return "Cobalt"
        case .emerald: return "Emerald"
        case .solarAmber: return "Amber"
        case .hyperViolet: return "Violet"
        case .titanium: return "Titanium"
        case .liquidGlass: return "Liquid Glass"
        case .light: return "Monochrome White"
        case .rose: return "Rose"
        case .cream: return "Cream"
        case .sage: return "Sage"
        }
    }

    var icon: String {
        isDark ? "moon.fill" : "sun.max.fill"
    }
}

enum OutputNamingTemplate: String, CaseIterable, Identifiable {
    case standard = "Standard ({name}.{ext})"
    case suffixFormat = "Format Suffix ({name}_{format}.{ext})"
    case timestamp = "Timestamped ({name}_{date}.{ext})"
    case compressed = "Compressed Tag ({name}-compressed.{ext})"

    var id: String { rawValue }
}

enum NavigationLayoutMode: String, CaseIterable, Identifiable {
    case unified = "Unified Dropzone (Tossy 2)"
    case classic = "Classic Tabs (Images, Video, Audio)"

    var id: String { rawValue }

    var shortTitle: String {
        switch self {
        case .unified: return "Unified Dropzone"
        case .classic: return "Classic Tabs"
        }
    }
}

enum FinderActionBehavior: String, CaseIterable, Identifiable {
    case silentBackground = "Convert silently in background"
    case openInApp = "Open in Tossy batch queue"

    var id: String { rawValue }
}

enum RecordingScaleMode: String, CaseIterable, Identifiable {
    case responsive = "Responsive Auto-Scale"
    case standard = "Standard (1.0x)"
    case retina1440p = "Retina 1440p (1.15x)"
    case cinema4K = "Cinema 4K (1.30x)"

    var id: String { rawValue }

    var shortTitle: String {
        switch self {
        case .responsive: return "Auto"
        case .standard: return "1.0x"
        case .retina1440p: return "1.15x"
        case .cinema4K: return "1.3x"
        }
    }
    
    var baseMultiplier: CGFloat {
        switch self {
        case .responsive: return 1.0
        case .standard: return 1.0
        case .retina1440p: return 1.15
        case .cinema4K: return 1.30
        }
    }
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
    var targetBitrateKbps: Int = 4500 // When encodingMode is "bitrate"
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

    var launchAtLogin: Bool {
        didSet {
            UserDefaults.standard.set(launchAtLogin, forKey: "launchAtLogin")
            if #available(macOS 13.0, *) {
                do {
                    if launchAtLogin {
                        if SMAppService.mainApp.status != .enabled {
                            try SMAppService.mainApp.register()
                        }
                    } else {
                        if SMAppService.mainApp.status == .enabled {
                            try SMAppService.mainApp.unregister()
                        }
                    }
                } catch {
                    // Registration may fail outside an installed .app bundle
                }
            }
        }
    }

    var namingTemplate: OutputNamingTemplate {
        didSet { UserDefaults.standard.set(namingTemplate.rawValue, forKey: "namingTemplate") }
    }

    var appTheme: AppTheme {
        didSet { UserDefaults.standard.set(appTheme.rawValue, forKey: "appTheme") }
    }

    var followSystemAppearance: Bool {
        didSet { UserDefaults.standard.set(followSystemAppearance, forKey: "followSystemAppearance") }
    }

    var preferredDarkTheme: AppTheme {
        didSet { UserDefaults.standard.set(preferredDarkTheme.rawValue, forKey: "preferredDarkTheme") }
    }

    var preferredLightTheme: AppTheme {
        didSet { UserDefaults.standard.set(preferredLightTheme.rawValue, forKey: "preferredLightTheme") }
    }

    func activeTheme(for colorScheme: ColorScheme?) -> AppTheme {
        guard followSystemAppearance, let colorScheme else { return appTheme }
        switch colorScheme {
        case .dark:
            return preferredDarkTheme
        case .light:
            return preferredLightTheme
        @unknown default:
            return appTheme
        }
    }

    var navigationLayoutMode: NavigationLayoutMode {
        didSet { UserDefaults.standard.set(navigationLayoutMode.rawValue, forKey: "navigationLayoutMode") }
    }

    var recordingScaleMode: RecordingScaleMode {
        didSet { UserDefaults.standard.set(recordingScaleMode.rawValue, forKey: "recordingScaleMode") }
    }

    var automaticallyCheckForUpdates: Bool {
        didSet { UserDefaults.standard.set(automaticallyCheckForUpdates, forKey: "automaticallyCheckForUpdates") }
    }

    var skippedUpdateVersion: String? {
        didSet { UserDefaults.standard.set(skippedUpdateVersion, forKey: "skippedUpdateVersion") }
    }

    var lastUpdateCheckDate: Date? {
        didSet { UserDefaults.standard.set(lastUpdateCheckDate, forKey: "lastUpdateCheckDate") }
    }

    var lastSeenWhatsNewVersion: String? {
        didSet { UserDefaults.standard.set(lastSeenWhatsNewVersion, forKey: "lastSeenWhatsNewVersion") }
    }

    var finderActionBehavior: FinderActionBehavior {
        didSet { UserDefaults.standard.set(finderActionBehavior.rawValue, forKey: "finderActionBehavior") }
    }

    var enabledFinderFormats: [String] {
        didSet { UserDefaults.standard.set(enabledFinderFormats, forKey: "enabledFinderFormats") }
    }

    // MARK: - Community & Conversion Metrics
    var hasPromptedForGitHubStar: Bool {
        didSet { UserDefaults.standard.set(hasPromptedForGitHubStar, forKey: "hasPromptedForGitHubStar") }
    }

    var completedConversionsCount: Int {
        didSet { UserDefaults.standard.set(completedConversionsCount, forKey: "completedConversionsCount") }
    }

    var shouldShowGitHubStarPrompt: Bool {
        !hasPromptedForGitHubStar && completedConversionsCount >= 1
    }

    func recordSuccessfulConversion(count: Int = 1) {
        completedConversionsCount += max(1, count)
    }

    func dismissGitHubStarPrompt() {
        hasPromptedForGitHubStar = true
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
    private var configCache: [String: Any] = [:]

    private func getCachedConfig<T: Codable>(forKey key: String, default: T) -> T {
        if let cached = configCache[key] as? T { return cached }
        let loaded: T = Self.loadJSON(forKey: key) ?? `default`
        configCache[key] = loaded
        return loaded
    }

    private func setCachedConfig<T: Codable>(_ value: T, forKey key: String) {
        configCache[key] = value
        saveJSON(value, forKey: key)
    }

    var webpConfig: WebPConfig {
        get { getCachedConfig(forKey: "webpConfig", default: WebPConfig()) }
        set { setCachedConfig(newValue, forKey: "webpConfig") }
    }
    var jxlConfig: JXLConfig {
        get { getCachedConfig(forKey: "jxlConfig", default: JXLConfig()) }
        set { setCachedConfig(newValue, forKey: "jxlConfig") }
    }
    var jpegConfig: JPEGConfig {
        get { getCachedConfig(forKey: "jpegConfig", default: JPEGConfig()) }
        set { setCachedConfig(newValue, forKey: "jpegConfig") }
    }
    var pngConfig: PNGConfig {
        get { getCachedConfig(forKey: "pngConfig", default: PNGConfig()) }
        set { setCachedConfig(newValue, forKey: "pngConfig") }
    }
    var tiffConfig: TIFFConfig {
        get { getCachedConfig(forKey: "tiffConfig", default: TIFFConfig()) }
        set { setCachedConfig(newValue, forKey: "tiffConfig") }
    }
    var gifConfig: GIFConfig {
        get { getCachedConfig(forKey: "gifConfig", default: GIFConfig()) }
        set { setCachedConfig(newValue, forKey: "gifConfig") }
    }
    var videoConfig: VideoConfig {
        get { getCachedConfig(forKey: "videoConfig", default: VideoConfig()) }
        set { setCachedConfig(newValue, forKey: "videoConfig") }
    }
    var audioConfig: AudioConfig {
        get { getCachedConfig(forKey: "audioConfig", default: AudioConfig()) }
        set { setCachedConfig(newValue, forKey: "audioConfig") }
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
        self.launchAtLogin = defaults.bool(forKey: "launchAtLogin")

        if #available(macOS 13.0, *) {
            Task.detached(priority: .utility) {
                let status = SMAppService.mainApp.status
                if status == .enabled {
                    await MainActor.run { AppSettings.shared.launchAtLogin = true }
                } else if status == .notRegistered {
                    await MainActor.run { AppSettings.shared.launchAtLogin = false }
                }
            }
        }

        let templateRaw = defaults.string(forKey: "namingTemplate") ?? OutputNamingTemplate.standard.rawValue
        self.namingTemplate = OutputNamingTemplate(rawValue: templateRaw) ?? .standard

        let themeRaw = defaults.string(forKey: "appTheme") ?? AppTheme.dark.rawValue
        self.appTheme = AppTheme(rawValue: themeRaw) ?? .dark

        self.followSystemAppearance = defaults.object(forKey: "followSystemAppearance") as? Bool ?? false
        let darkRaw = defaults.string(forKey: "preferredDarkTheme") ?? AppTheme.dark.rawValue
        self.preferredDarkTheme = AppTheme(rawValue: darkRaw) ?? .dark
        let lightRaw = defaults.string(forKey: "preferredLightTheme") ?? AppTheme.light.rawValue
        self.preferredLightTheme = AppTheme(rawValue: lightRaw) ?? .light

        let layoutRaw = defaults.string(forKey: "navigationLayoutMode") ?? NavigationLayoutMode.unified.rawValue
        self.navigationLayoutMode = NavigationLayoutMode(rawValue: layoutRaw) ?? .unified

        let scaleRaw = defaults.string(forKey: "recordingScaleMode") ?? RecordingScaleMode.responsive.rawValue
        self.recordingScaleMode = RecordingScaleMode(rawValue: scaleRaw) ?? .responsive

        self.automaticallyCheckForUpdates = defaults.object(forKey: "automaticallyCheckForUpdates") as? Bool ?? true
        self.skippedUpdateVersion = defaults.string(forKey: "skippedUpdateVersion")
        self.lastUpdateCheckDate = defaults.object(forKey: "lastUpdateCheckDate") as? Date
        self.lastSeenWhatsNewVersion = defaults.string(forKey: "lastSeenWhatsNewVersion")

        let finderBehaviorRaw = defaults.string(forKey: "finderActionBehavior") ?? FinderActionBehavior.silentBackground.rawValue
        self.finderActionBehavior = FinderActionBehavior(rawValue: finderBehaviorRaw) ?? .silentBackground

        self.enabledFinderFormats = defaults.stringArray(forKey: "enabledFinderFormats") ?? ["png", "jpeg", "webp", "mp4", "mp3", "flac"]
        self.hasPromptedForGitHubStar = defaults.bool(forKey: "hasPromptedForGitHubStar")
        self.completedConversionsCount = defaults.integer(forKey: "completedConversionsCount")
        
        if let stored = defaults.object(forKey: "maxFileSizeBytes") as? NSNumber {
            let val = stored.int64Value
            self.maxFileSizeBytes = val < 0 ? nil : val
        } else {
            self.maxFileSizeBytes = 4_000_000_000
        }
    }
    
    func destinationFolder(for sourceURL: URL) -> URL? {
        if destinationPolicy == .customFolder && !customDestinationPath.isEmpty {
            return URL(fileURLWithPath: customDestinationPath)
        }
        return sourceURL.deletingLastPathComponent()
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
