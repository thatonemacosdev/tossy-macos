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
        let which = Process()
        which.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        which.arguments = [binaryName]
        let pipe = Pipe()
        which.standardOutput = pipe
        which.standardError = Pipe()
        do {
            try which.run()
            which.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !path.isEmpty {
                return path
            }
        } catch {
            return nil
        }
        return nil
    }
}
