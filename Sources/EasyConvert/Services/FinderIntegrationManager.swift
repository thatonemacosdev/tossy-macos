import Foundation
import AppKit

@Observable
final class FinderIntegrationManager: @unchecked Sendable {
    static let shared = FinderIntegrationManager()
    
    var isInstalling: Bool = false
    var statusMessage: String? = nil
    var isInstalled: Bool = false
    
    var quickConvertFiles: [URL]? = nil
    var isShowingQuickConvert: Bool = false
    
    private init() {
        checkInstallationStatus()
    }
    
    // MARK: - Status Checking
    
    func checkInstallationStatus() {
        let servicesDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Services")
        let mainWorkflow = servicesDir.appendingPathComponent("Convert with Tossy.workflow")
        self.isInstalled = FileManager.default.fileExists(atPath: mainWorkflow.path)
    }
    
    // MARK: - Service Handling
    
    func handleServiceFiles(_ urls: [URL], targetFormat: String?) {
        guard !urls.isEmpty else { return }
        
        let settings = AppSettings.shared
        if let targetFormat {
            // Explicit format provided (e.g. from script or CLI)
            if settings.finderActionBehavior == .silentBackground {
                Task {
                    await HeadlessConversionWorker.shared.processFiles(urls, targetFormat: targetFormat, isSilent: true)
                }
            } else {
                Task { @MainActor in
                    NSApp.activate(ignoringOtherApps: true)
                    NotificationCenter.default.post(
                        name: NSNotification.Name("TossyEnqueueExternalFiles"),
                        object: nil,
                        userInfo: ["urls": urls, "targetFormat": targetFormat as Any]
                    )
                }
            }
        } else {
            // No format specified -> Open Mini Tossy Quick Convert window!
            Task { @MainActor in
                self.quickConvertFiles = urls
                self.isShowingQuickConvert = true
                NSApp.activate(ignoringOtherApps: true)
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
        statusMessage = "Installing 'Convert with Tossy' in Finder…"
        
        Task {
            let servicesDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Services")
            try? FileManager.default.createDirectory(at: servicesDir, withIntermediateDirectories: true)
            
            // Clean up any legacy per-format workflows
            uninstallLegacyWorkflows()
            
            // Create the single unified "Convert with Tossy" Quick Action
            let mainWorkflowName = "Convert with Tossy.workflow"
            let targetURL = servicesDir.appendingPathComponent(mainWorkflowName)
            
            let success = createUnifiedQuickActionWorkflow(at: targetURL)
            
            // Refresh macOS Services cache
            let pbsProcess = Process()
            pbsProcess.executableURL = URL(fileURLWithPath: "/System/Library/CoreServices/pbs")
            pbsProcess.arguments = ["-flush"]
            try? pbsProcess.run()
            pbsProcess.waitUntilExit()
            
            await MainActor.run {
                self.isInstalling = false
                self.checkInstallationStatus()
                self.statusMessage = success ? "Successfully installed 'Convert with Tossy' Quick Action!" : "Failed to install Quick Action."
            }
        }
    }
    
    func uninstallQuickActions() {
        let servicesDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Services")
        let fileManager = FileManager.default
        
        let mainWorkflow = servicesDir.appendingPathComponent("Convert with Tossy.workflow")
        try? fileManager.removeItem(at: mainWorkflow)
        
        uninstallLegacyWorkflows()
        
        checkInstallationStatus()
        statusMessage = "Removed Finder Quick Action."
    }
    
    private func uninstallLegacyWorkflows() {
        let servicesDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Services")
        let fileManager = FileManager.default
        
        if let contents = try? fileManager.contentsOfDirectory(at: servicesDir, includingPropertiesForKeys: nil) {
            for item in contents {
                if item.lastPathComponent.hasPrefix("Convert to ") && item.lastPathComponent.hasSuffix(" with Tossy.workflow") {
                    try? fileManager.removeItem(at: item)
                }
            }
        }
    }
    
    private func createUnifiedQuickActionWorkflow(at targetURL: URL) -> Bool {
        let fileManager = FileManager.default
        try? fileManager.removeItem(at: targetURL)
        
        let contentsDir = targetURL.appendingPathComponent("Contents")
        let resourcesDir = contentsDir.appendingPathComponent("Resources")
        try? fileManager.createDirectory(at: resourcesDir, withIntermediateDirectories: true)
        
        let actionUUID = UUID().uuidString.uppercased()
        let inputUUID = UUID().uuidString.uppercased()
        let outputUUID = UUID().uuidString.uppercased()
        
        let script = """
        for f in "$@"; do
            encoded=$(python3 -c "import urllib.parse, sys; print(urllib.parse.quote(sys.argv[1]))" "$f" 2>/dev/null || echo "$f")
            open "tossy://convert?files=$encoded"
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
                        <key>AMAccepts</key>
                        <dict>
                            <key>Container</key>
                            <string>List</string>
                            <key>Optional</key>
                            <true/>
                            <key>Types</key>
                            <array>
                                <string>com.apple.cocoa.path</string>
                            </array>
                        </dict>
                        <key>AMActionVersion</key>
                        <string>2.0.3</string>
                        <key>AMParameterProperties</key>
                        <dict>
                            <key>COMMAND_STRING</key>
                            <dict/>
                            <key>CheckedForUserDefaultShell</key>
                            <dict/>
                            <key>inputMethod</key>
                            <dict/>
                            <key>shell</key>
                            <dict/>
                            <key>source</key>
                            <dict/>
                        </dict>
                        <key>AMProvides</key>
                        <dict>
                            <key>Container</key>
                            <string>List</string>
                            <key>Types</key>
                            <array>
                                <string>com.apple.cocoa.path</string>
                            </array>
                        </dict>
                        <key>ActionBundlePath</key>
                        <string>/System/Library/Automator/Run Shell Script.action</string>
                        <key>ActionName</key>
                        <string>Run Shell Script</string>
                        <key>ActionParameters</key>
                        <dict>
                            <key>COMMAND_STRING</key>
                            <string>\(escapedScript)</string>
                            <key>CheckedForUserDefaultShell</key>
                            <true/>
                            <key>inputMethod</key>
                            <integer>1</integer>
                            <key>shell</key>
                            <string>/bin/zsh</string>
                            <key>source</key>
                            <string></string>
                        </dict>
                        <key>BundleIdentifier</key>
                        <string>com.apple.RunShellScript</string>
                        <key>CFBundleVersion</key>
                        <string>2.0.3</string>
                        <key>CanShowSelectedItemsWhenRun</key>
                        <false/>
                        <key>CanShowWhenRun</key>
                        <true/>
                        <key>Class Name</key>
                        <string>RunShellScriptAction</string>
                        <key>InputUUID</key>
                        <string>\(inputUUID)</string>
                        <key>Keywords</key>
                        <array>
                            <string>Shell</string>
                            <string>Script</string>
                            <string>Command</string>
                            <string>Run</string>
                            <string>Unix</string>
                        </array>
                        <key>OutputUUID</key>
                        <string>\(outputUUID)</string>
                        <key>UUID</key>
                        <string>\(actionUUID)</string>
                        <key>UnlocalizedApplications</key>
                        <array>
                            <string>Automator</string>
                        </array>
                        <key>arguments</key>
                        <dict/>
                        <key>isViewVisible</key>
                        <integer>1</integer>
                        <key>location</key>
                        <string>449.000000:305.000000</string>
                        <key>nibPath</key>
                        <string>/System/Library/Automator/Run Shell Script.action/Contents/Resources/Base.lproj/main.nib</string>
                    </dict>
                    <key>isViewVisible</key>
                    <integer>1</integer>
                </dict>
            </array>
            <key>connectors</key>
            <dict/>
            <key>workflowMetaData</key>
            <dict>
                <key>applicationBundleIDsByPath</key>
                <dict/>
                <key>applicationPaths</key>
                <array/>
                <key>inputTypeIdentifier</key>
                <string>com.apple.Automator.fileSystemObject</string>
                <key>outputTypeIdentifier</key>
                <string>com.apple.Automator.nothing</string>
                <key>presentationMode</key>
                <integer>15</integer>
                <key>processesInput</key>
                <integer>0</integer>
                <key>serviceInputTypeIdentifier</key>
                <string>com.apple.Automator.fileSystemObject</string>
                <key>serviceOutputTypeIdentifier</key>
                <string>com.apple.Automator.nothing</string>
                <key>serviceProcessesInput</key>
                <integer>0</integer>
                <key>systemImageName</key>
                <string>NSActionTemplate</string>
                <key>useAutomaticInputType</key>
                <integer>0</integer>
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
            <key>CFBundleDevelopmentRegion</key>
            <string>en_US</string>
            <key>CFBundleIdentifier</key>
            <string>com.easyconvert.quickaction.convertWithTossy</string>
            <key>CFBundleName</key>
            <string>Convert with Tossy</string>
            <key>CFBundleShortVersionString</key>
            <string>1.0</string>
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
                        <string>Convert with Tossy</string>
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
                        <string>public.item</string>
                    </array>
                </dict>
            </array>
        </dict>
        </plist>
        """
        
        let versionPlist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>CFBundleShortVersionString</key>
            <string>1.0</string>
            <key>CFBundleVersion</key>
            <string>1.0</string>
        </dict>
        </plist>
        """
        
        do {
            try documentPlist.write(to: contentsDir.appendingPathComponent("document.wflow"), atomically: true, encoding: .utf8)
            try documentPlist.write(to: resourcesDir.appendingPathComponent("document.wflow"), atomically: true, encoding: .utf8)
            try infoPlist.write(to: contentsDir.appendingPathComponent("Info.plist"), atomically: true, encoding: .utf8)
            try versionPlist.write(to: contentsDir.appendingPathComponent("version.plist"), atomically: true, encoding: .utf8)
            return true
        } catch {
            return false
        }
    }
}
