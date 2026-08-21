import Foundation
import AppKit

struct AppReleaseInfo: Identifiable, Sendable {
    let id: Int
    let tagName: String
    let name: String
    let body: String
    let publishedAt: String
    let htmlURL: URL
    let dmgDownloadURL: URL?
    let dmgSizeBytes: Int64?
    let zipDownloadURL: URL?
    let zipSizeBytes: Int64?
    
    var versionNumber: String {
        tagName.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
    }
}

@Observable
final class UpdateManager: NSObject, @unchecked Sendable {
    static let shared = UpdateManager()
    
    var isChecking: Bool = false
    var availableUpdate: AppReleaseInfo? = nil
    var isShowingUpdateModal: Bool = false
    
    var isDownloading: Bool = false
    var downloadProgress: Double = 0.0
    var downloadedBytes: Int64 = 0
    var totalBytes: Int64 = 0
    var installStatusText: String = ""
    var errorMessage: String? = nil
    
    var isUpToDateBannerShowing: Bool = false
    
    private var downloadTask: URLSessionDownloadTask?
    private var downloadSession: URLSession?
    
    override init() {
        super.init()
    }
    
    // MARK: - Version Comparison
    
    static func isVersion(_ newVer: String, newerThan currentVer: String) -> Bool {
        let cleanNew = newVer.trimmingCharacters(in: CharacterSet(charactersIn: "vV")).split(separator: ".").compactMap { Int($0) }
        let cleanCur = currentVer.trimmingCharacters(in: CharacterSet(charactersIn: "vV")).split(separator: ".").compactMap { Int($0) }
        for i in 0..<max(cleanNew.count, cleanCur.count) {
            let vNew = i < cleanNew.count ? cleanNew[i] : 0
            let vCur = i < cleanCur.count ? cleanCur[i] : 0
            if vNew > vCur { return true }
            if vNew < vCur { return false }
        }
        return false
    }
    
    // MARK: - Check for Updates
    
    func checkForUpdates(isUserInitiated: Bool = false) {
        guard !isChecking else { return }
        
        isChecking = true
        errorMessage = nil
        isUpToDateBannerShowing = false
        
        Task {
            defer {
                Task { @MainActor in
                    self.isChecking = false
                }
            }
            
            let apiURL = URL(string: "https://api.github.com/repos/thatonemacosdev/tossy-macos/releases/latest")!
            var request = URLRequest(url: apiURL)
            request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
            request.setValue("Tossy-macOS-Updater", forHTTPHeaderField: "User-Agent")
            request.timeoutInterval = 10.0
            
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    if isUserInitiated {
                        await MainActor.run {
                            self.errorMessage = "Unable to reach the update server. Please check your internet connection."
                        }
                    }
                    return
                }
                
                guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let id = json["id"] as? Int,
                      let tagName = json["tag_name"] as? String,
                      let name = json["name"] as? String,
                      let body = json["body"] as? String,
                      let publishedAt = json["published_at"] as? String,
                      let htmlUrlStr = json["html_url"] as? String,
                      let htmlURL = URL(string: htmlUrlStr) else {
                    if isUserInitiated {
                        await MainActor.run {
                            self.errorMessage = "Received unexpected response format from update server."
                        }
                    }
                    return
                }
                
                var dmgURL: URL?
                var dmgSize: Int64?
                var zipURL: URL?
                var zipSize: Int64?
                
                if let assets = json["assets"] as? [[String: Any]] {
                    for asset in assets {
                        guard let assetName = asset["name"] as? String,
                              let downloadUrlStr = asset["browser_download_url"] as? String,
                              let downloadURL = URL(string: downloadUrlStr) else { continue }
                        let size = (asset["size"] as? NSNumber)?.int64Value
                        
                        if assetName.lowercased().hasSuffix(".dmg") {
                            dmgURL = downloadURL
                            dmgSize = size
                        } else if assetName.lowercased().hasSuffix(".zip") {
                            zipURL = downloadURL
                            zipSize = size
                        }
                    }
                }
                
                let release = AppReleaseInfo(
                    id: id,
                    tagName: tagName,
                    name: name,
                    body: body,
                    publishedAt: publishedAt,
                    htmlURL: htmlURL,
                    dmgDownloadURL: dmgURL,
                    dmgSizeBytes: dmgSize,
                    zipDownloadURL: zipURL,
                    zipSizeBytes: zipSize
                )
                
                await MainActor.run {
                    AppSettings.shared.lastUpdateCheckDate = Date()
                    let currentVersion = AppVersion.string
                    
                    if Self.isVersion(release.versionNumber, newerThan: currentVersion) {
                        if !isUserInitiated && AppSettings.shared.skippedUpdateVersion == release.tagName {
                            // User previously skipped this version during background check
                            return
                        }
                        self.availableUpdate = release
                        self.isShowingUpdateModal = true
                    } else {
                        if isUserInitiated {
                            self.isUpToDateBannerShowing = true
                        }
                    }
                }
            } catch {
                if isUserInitiated {
                    await MainActor.run {
                        self.errorMessage = "Failed to check for updates: \(error.localizedDescription)"
                    }
                }
            }
        }
    }
    
    // MARK: - Download & Install
    
    func downloadAndInstall(release: AppReleaseInfo) {
        guard let downloadURL = release.zipDownloadURL ?? release.dmgDownloadURL else {
            NSWorkspace.shared.open(release.htmlURL)
            return
        }
        
        isDownloading = true
        downloadProgress = 0.0
        downloadedBytes = 0
        totalBytes = release.dmgSizeBytes ?? release.zipSizeBytes ?? 0
        installStatusText = "Connecting to download server…"
        errorMessage = nil
        
        let config = URLSessionConfiguration.default
        downloadSession = URLSession(configuration: config, delegate: self, delegateQueue: .main)
        downloadTask = downloadSession?.downloadTask(with: downloadURL)
        downloadTask?.resume()
    }
    
    func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
        isDownloading = false
        installStatusText = ""
        downloadProgress = 0.0
    }
    
    func skipVersion(_ tagName: String) {
        AppSettings.shared.skippedUpdateVersion = tagName
        isShowingUpdateModal = false
    }
}

// MARK: - URLSessionDownloadDelegate & Installation Pipeline

extension UpdateManager: URLSessionDownloadDelegate {
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        self.downloadedBytes = totalBytesWritten
        self.totalBytes = max(totalBytesExpectedToWrite, totalBytesWritten)
        if totalBytesExpectedToWrite > 0 {
            self.downloadProgress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            let downloadedMB = Double(totalBytesWritten) / 1_000_000.0
            let totalMB = Double(totalBytesExpectedToWrite) / 1_000_000.0
            self.installStatusText = String(format: "Downloading installer: %.1f MB / %.1f MB (%.0f%%)", downloadedMB, totalMB, self.downloadProgress * 100)
        } else {
            let downloadedMB = Double(totalBytesWritten) / 1_000_000.0
            self.installStatusText = String(format: "Downloading installer: %.1f MB", downloadedMB)
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        Task {
            await performInstallation(fromTempFile: location)
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error as NSError?, error.code != NSURLErrorCancelled {
            Task { @MainActor in
                self.isDownloading = false
                self.errorMessage = "Download failed: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Native In-Place Replacement
    
    private func performInstallation(fromTempFile tempLocation: URL) async {
        await MainActor.run {
            self.installStatusText = "Mounting and verifying installer…"
            self.downloadProgress = 1.0
        }
        
        let fileManager = FileManager.default
        let currentAppURL = Bundle.main.bundleURL
        let isDMG = (downloadTask?.originalRequest?.url?.pathExtension.lowercased() ?? "dmg") == "dmg"
        
        let stagingDir = fileManager.temporaryDirectory.appendingPathComponent("TossyUpdateStaging_\(UUID().uuidString)")
        do {
            try fileManager.createDirectory(at: stagingDir, withIntermediateDirectories: true)
        } catch {
            await MainActor.run {
                self.isDownloading = false
                self.errorMessage = "Failed to create installation staging area."
            }
            return
        }
        
        var sourceAppURL: URL?
        var mountedMountPoint: URL?
        
        if isDMG {
            let mountPoint = stagingDir.appendingPathComponent("mount")
            do {
                try fileManager.createDirectory(at: mountPoint, withIntermediateDirectories: true)
            } catch {}
            
            // Non-interactive DMG mount
            let attachProcess = Process()
            attachProcess.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
            attachProcess.arguments = ["attach", "-nobrowse", "-readonly", "-mountpoint", mountPoint.path, tempLocation.path]
            
            do {
                try attachProcess.run()
                attachProcess.waitUntilExit()
                if attachProcess.terminationStatus == 0 {
                    mountedMountPoint = mountPoint
                    let appInDMG = mountPoint.appendingPathComponent("Tossy.app")
                    if fileManager.fileExists(atPath: appInDMG.path) {
                        sourceAppURL = appInDMG
                    }
                }
            } catch {}
        } else {
            // Zip extraction
            let unzipProcess = Process()
            unzipProcess.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
            unzipProcess.arguments = ["-x", "-k", tempLocation.path, stagingDir.path]
            do {
                try unzipProcess.run()
                unzipProcess.waitUntilExit()
                let appInZip = stagingDir.appendingPathComponent("Tossy.app")
                if fileManager.fileExists(atPath: appInZip.path) {
                    sourceAppURL = appInZip
                }
            } catch {}
        }
        
        guard let validSourceApp = sourceAppURL else {
            if let mount = mountedMountPoint {
                let detach = Process()
                detach.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
                detach.arguments = ["detach", mount.path, "-force"]
                try? detach.run()
                detach.waitUntilExit()
            }
            try? fileManager.removeItem(at: stagingDir)
            
            await MainActor.run {
                self.isDownloading = false
                self.errorMessage = "Could not locate Tossy.app in the downloaded installer."
            }
            return
        }
        
        await MainActor.run {
            self.installStatusText = "Installing updated Tossy into /Applications…"
        }
        
        // Execute atomic replacement and relaunch
        let script = """
        sleep 1
        ditto "\(validSourceApp.path)" "\(currentAppURL.path)"
        if [ -d "\(mountedMountPoint?.path ?? "")" ]; then
            hdiutil detach "\(mountedMountPoint?.path ?? "")" -force 2>/dev/null || true
        fi
        rm -rf "\(stagingDir.path)" 2>/dev/null || true
        open -n -b com.easyconvert.app
        """
        
        let relaunchHelper = Process()
        relaunchHelper.executableURL = URL(fileURLWithPath: "/bin/bash")
        relaunchHelper.arguments = ["-c", script]
        
        do {
            try relaunchHelper.run()
            await MainActor.run {
                self.installStatusText = "Relaunching Tossy…"
            }
            try await Task.sleep(nanoseconds: 500_000_000)
            await MainActor.run {
                NSApp.terminate(nil)
            }
        } catch {
            await MainActor.run {
                self.isDownloading = false
                self.errorMessage = "Failed to launch application replacement: \(error.localizedDescription)"
            }
        }
    }
}
