import Foundation

enum AppVersion {
    static let fallback = "2.2.0"

    static var string: String {
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
           let bundleID = Bundle.main.bundleIdentifier,
           (bundleID.contains("Tossy") || bundleID.contains("easyconvert")) {
            return version
        }
        return fallback
    }

    static var build: String {
        if let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String,
           let bundleID = Bundle.main.bundleIdentifier,
           (bundleID.contains("Tossy") || bundleID.contains("easyconvert")) {
            return build
        }
        return fallback
    }

    static let displayName = "Tossy 2.2"
}
