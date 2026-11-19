import Foundation

/// Locates the `ffmpeg`/`ffprobe` binaries: prefers the copy bundled inside the app
/// (Contents/Resources/ffmpeg/), falling back to common install locations so the app
/// still works when run directly via `swift run` during development.
enum FFmpegLocator {
    static let ffmpegPath: String? = locate(binaryName: "ffmpeg")
    static let ffprobePath: String? = locate(binaryName: "ffprobe")

    static var isAvailable: Bool { ffmpegPath != nil && ffprobePath != nil }

    private static func locate(binaryName: String) -> String? {
        var candidates: [String] = []

        if let resourceURL = Bundle.main.resourceURL {
            candidates.append(resourceURL.appendingPathComponent("ffmpeg/\(binaryName)").path)
        }

        candidates.append(contentsOf: [
            "/opt/homebrew/bin/\(binaryName)",
            "/usr/local/bin/\(binaryName)"
        ])

        for candidate in candidates where FileManager.default.isExecutableFile(atPath: candidate) {
            return candidate
        }

        // Last resort: whatever's on PATH.
        if Thread.isMainThread {
            return DispatchQueue.global(qos: .userInitiated).sync {
                runWhich(binaryName: binaryName)
            }
        } else {
            return runWhich(binaryName: binaryName)
        }
    }

    private static func runWhich(binaryName: String) -> String? {
        let result = SubprocessRunner.runSync(executablePath: "/usr/bin/which", arguments: [binaryName])
        let path = result.stdoutString.trimmingCharacters(in: .whitespacesAndNewlines)
        return path.isEmpty ? nil : path
    }
}
