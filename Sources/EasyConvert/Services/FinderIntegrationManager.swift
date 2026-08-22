import Foundation
import AppKit

@Observable
final class FinderIntegrationManager: @unchecked Sendable {
    static let shared = FinderIntegrationManager()
    
    var isInstalling: Bool = false
    var statusMessage: String? = nil
    var isInstalled: Bool = false
    
    private init() {
        checkInstallationStatus()
    }
    
    // MARK: - Status Checking
    
    func checkInstallationStatus() {
        let servicesDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Services")
        let testWorkflow = servicesDir.appendingPathComponent("Convert to PNG with Tossy.workflow")
        self.isInstalled = FileManager.default.fileExists(atPath: testWorkflow.path)
    }
    
    // MARK: - Service Handling
    
    func handleServiceFiles(_ urls: [URL], targetFormat: String?) {
        guard !urls.isEmpty else { return }
        
        let settings = AppSettings.shared
        if settings.finderActionBehavior == .silentBackground {
            Task {
                await HeadlessConversionWorker.shared.processFiles(urls, targetFormat: targetFormat, isSilent: true)
            }
        } else {
            // Interactive mode: Open main window and enqueue files
            Task { @MainActor in
                NSApp.activate(ignoringOtherApps: true)
                NotificationCenter.default.post(
                    name: NSNotification.Name("TossyEnqueueExternalFiles"),
                    object: nil,
                    userInfo: ["urls": urls, "targetFormat": targetFormat as Any]
                )
            }
        }
    }
    
    // MARK: - URL Scheme Handling (tossy://convert?format=png&files=...)
    
    func handleURL(_ url: URL) {
        guard url.scheme?.lowercased() == "tossy" else { return }
        
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true) else { return }
        var targetFormat: String? = nil
        var filePaths: [String] = []
        
        if let queryItems = components.queryItems {
            for item in queryItems {
                if item.name.lowercased() == "format" {
                    targetFormat = item.value
                } else if item.name.lowercased() == "files" || item.name.lowercased() == "file" {
                    if let val = item.value {
                        filePaths.append(contentsOf: val.components(separatedBy: ","))
                    }
                }
            }
        }
        
        let validURLs = filePaths.compactMap { path -> URL? in
            let unescaped = path.removingPercentEncoding ?? path
            let clean = unescaped.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !clean.isEmpty else { return nil }
            return URL(fileURLWithPath: clean)
        }
        
        if !validURLs.isEmpty {
            handleServiceFiles(validURLs, targetFormat: targetFormat)
        }
    }
    
    // MARK: - Quick Action Workflow Generation & Installation
    
    func installQuickActions() {
        isInstalling = true
        statusMessage = "Installing Quick Actions in Finder…"
        
        Task {
            let formats = [
                ("PNG", "png", "public.image"),
                ("JPEG", "jpeg", "public.image"),
                ("WebP", "webp", "public.image"),
                ("JPEG XL", "jxl", "public.image"),
                ("MP4", "mp4", "public.movie"),
                ("WebM", "webm", "public.movie"),
                ("MP3", "mp3", "public.audio"),
                ("FLAC", "flac", "public.audio"),
                ("WAV", "wav", "public.audio")
            ]
            
            let servicesDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Services")
            try? FileManager.default.createDirectory(at: servicesDir, withIntermediateDirectories: true)
            
            var successCount = 0
            for (title, ext, uti) in formats {
                let workflowName = "Convert to \(title) with Tossy.workflow"
                let targetURL = servicesDir.appendingPathComponent(workflowName)
                
                if createQuickActionWorkflow(at: targetURL, formatTitle: title, formatExt: ext, inputType: uti) {
                    successCount += 1
                }
            }
            
            // Refresh macOS Services cache
            let pbsProcess = Process()
            pbsProcess.executableURL = URL(fileURLWithPath: "/System/Library/CoreServices/pbs")
            pbsProcess.arguments = ["-flush"]
            try? pbsProcess.run()
            pbsProcess.waitUntilExit()
            
            let finalCount = successCount
            await MainActor.run {
                self.isInstalling = false
                self.checkInstallationStatus()
                self.statusMessage = "Successfully installed \(finalCount) Finder Quick Actions!"
            }
        }
    }
    
    func uninstallQuickActions() {
        let servicesDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Services")
        let fileManager = FileManager.default
        
        if let contents = try? fileManager.contentsOfDirectory(at: servicesDir, includingPropertiesForKeys: nil) {
            for item in contents {
                if item.lastPathComponent.hasPrefix("Convert to ") && item.lastPathComponent.hasSuffix(" with Tossy.workflow") {
                    try? fileManager.removeItem(at: item)
                }
            }
        }
        
        checkInstallationStatus()
        statusMessage = "Removed Finder Quick Actions."
    }
    
    private func createQuickActionWorkflow(at targetURL: URL, formatTitle: String, formatExt: String, inputType: String) -> Bool {
        let fileManager = FileManager.default
        try? fileManager.removeItem(at: targetURL)
        
        let contentsDir = targetURL.appendingPathComponent("Contents")
        try? fileManager.createDirectory(at: contentsDir, withIntermediateDirectories: true)
        
        let script = """
        for f in "$@"; do
            encoded=$(python3 -c "import urllib.parse, sys; print(urllib.parse.quote(sys.argv[1]))" "$f" 2>/dev/null || echo "$f")
            open "tossy://convert?format=\(formatExt)&files=$encoded"
        done
        """
        
        let escapedScript = script
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
        
        let documentPlist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>AMApplicationBuild</key>
            <string>523</string>
            <key>AMApplicationVersion</key>
            <string>2.10</string>
            <key>AMDocumentVersion</key>
            <string>2</string>
            <key>actions</key>
            <array>
                <dict>
                    <key>action</key>
                    <dict>
                        <key>ActionBundlePath</key>
                        <string>/System/Library/Automator/Run Shell Script.action</string>
                        <key>ActionName</key>
                        <string>Run Shell Script</string>
                        <key>ActionParameters</key>
                        <dict>
                            <key>COMMAND_STRING</key>
                            <string>\(escapedScript)</string>
                            <key>inputMethod</key>
                            <integer>1</integer>
                            <key>shell</key>
                            <string>/bin/zsh</string>
                            <key>source</key>
                            <string></string>
                        </dict>
                    </dict>
                </dict>
            </array>
            <key>connectors</key>
            <dict/>
            <key>workflowMetaData</key>
            <dict>
                <key>workflowTypeIdentifier</key>
                <string>com.apple.Automator.servicesMenu</string>
            </dict>
        </dict>
        </plist>
        """
        
        let infoPlist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>NSServices</key>
            <array>
                <dict>
                    <key>NSBackgroundColorName</key>
                    <string>background</string>
                    <key>NSIconName</key>
                    <string>NSActionTemplate</string>
                    <key>NSMenuItem</key>
                    <dict>
                        <key>default</key>
                        <string>Convert to \(formatTitle) with Tossy</string>
                    </dict>
                    <key>NSMessage</key>
                    <string>runWorkflowAsService</string>
                    <key>NSRequiredContext</key>
                    <dict>
                        <key>NSApplicationIdentifier</key>
                        <string>com.apple.finder</string>
                    </dict>
                    <key>NSSendFileTypes</key>
                    <array>
                        <string>\(inputType)</string>
                        <string>public.item</string>
                    </array>
                </dict>
            </array>
        </dict>
        </plist>
        """
        
        do {
            try documentPlist.write(to: contentsDir.appendingPathComponent("document.wflow"), atomically: true, encoding: .utf8)
            try infoPlist.write(to: contentsDir.appendingPathComponent("Info.plist"), atomically: true, encoding: .utf8)
            return true
        } catch {
            return false
        }
    }
}
