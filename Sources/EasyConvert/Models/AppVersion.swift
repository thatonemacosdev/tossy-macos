import Foundation

enum AppVersion {
    /// Falls back to a hardcoded value during `swift run` (no real Info.plist in that context)  - 
    /// the packaged .app reads the real one from Info.plist via CFBundleShortVersionString.
    static let string = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.5.3"
}
