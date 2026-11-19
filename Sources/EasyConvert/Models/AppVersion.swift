import Foundation

enum AppVersion {
    static let string = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "2.2.0"
    static let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "2.2.0"
    static let displayName = "Tossy 2.2"
}
