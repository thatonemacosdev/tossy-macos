import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.servicesProvider = self
        NSRegisterServicesProvider(self, "Tossy")
        
        // Handle command line arguments if launched from CLI
        handleCommandLineArguments()
    }
    
    private func handleCommandLineArguments() {
        let args = CommandLine.arguments
        guard args.count > 1 else { return }
        
        var format: String? = nil
        var files: [URL] = []
        var isSilent = false
        
        var i = 1
        while i < args.count {
            let arg = args[i]
            if arg == "--format" || arg == "-f", i + 1 < args.count {
                format = args[i + 1]
                i += 2
            } else if arg == "--silent" || arg == "-s" {
                isSilent = true
                i += 1
            } else if arg == "--convert" || arg == "-c" {
                i += 1
            } else if !arg.hasPrefix("-") {
                let url = URL(fileURLWithPath: arg)
                if FileManager.default.fileExists(atPath: url.path) {
                    files.append(url)
                }
                i += 1
            } else {
                i += 1
            }
        }
        
        if !files.isEmpty {
            if isSilent {
                Task {
                    await HeadlessConversionWorker.shared.processFiles(files, targetFormat: format, isSilent: true)
                }
            } else {
                FinderIntegrationManager.shared.handleServiceFiles(files, targetFormat: format)
            }
        }
    }
    
    // MARK: - NSServices Callbacks
    
    @objc func convertService(_ pboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        let urls = extractURLs(from: pboard)
        FinderIntegrationManager.shared.handleServiceFiles(urls, targetFormat: nil)
    }
    
    @objc func convertToPngService(_ pboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        let urls = extractURLs(from: pboard)
        FinderIntegrationManager.shared.handleServiceFiles(urls, targetFormat: "png")
    }
    
    @objc func convertToJpegService(_ pboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        let urls = extractURLs(from: pboard)
        FinderIntegrationManager.shared.handleServiceFiles(urls, targetFormat: "jpeg")
    }
    
    @objc func convertToWebpService(_ pboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        let urls = extractURLs(from: pboard)
        FinderIntegrationManager.shared.handleServiceFiles(urls, targetFormat: "webp")
    }
    
    @objc func convertToMp4Service(_ pboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        let urls = extractURLs(from: pboard)
        FinderIntegrationManager.shared.handleServiceFiles(urls, targetFormat: "mp4")
    }
    
    @objc func convertToMp3Service(_ pboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        let urls = extractURLs(from: pboard)
        FinderIntegrationManager.shared.handleServiceFiles(urls, targetFormat: "mp3")
    }
    
    @objc func convertToFlacService(_ pboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        let urls = extractURLs(from: pboard)
        FinderIntegrationManager.shared.handleServiceFiles(urls, targetFormat: "flac")
    }
    
    private func extractURLs(from pboard: NSPasteboard) -> [URL] {
        guard let items = pboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] else {
            return []
        }
        return items
    }
}

@main
struct TossyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup("Tossy") {
            RootView()
                .frame(minWidth: 640, minHeight: 460)
                .onAppear {
                    MenuBarManager.shared.setupIfNeeded()
                    if AppSettings.shared.automaticallyCheckForUpdates {
                        UpdateManager.shared.checkForUpdates(isUserInitiated: false)
                    }
                }
                .onOpenURL { url in
                    FinderIntegrationManager.shared.handleURL(url)
                }
        }
        .windowResizability(.automatic)
        .defaultSize(width: 720, height: 540)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") {
                    UpdateManager.shared.checkForUpdates(isUserInitiated: true)
                }
                Divider()
            }
        }
        
        Settings {
            SettingsView()
        }
    }
}
