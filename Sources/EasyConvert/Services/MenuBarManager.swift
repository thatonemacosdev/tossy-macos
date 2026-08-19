import SwiftUI
import AppKit
import UniformTypeIdentifiers

@MainActor
final class MenuBarManager: NSObject, ObservableObject {
    static let shared = MenuBarManager()

    private var statusItem: NSStatusItem?
    private var isConfigured = false

    override private init() {
        super.init()
    }

    func setupIfNeeded() {
        guard !isConfigured else { return }
        isConfigured = true
        updateStatusItemVisibility()
    }

    func updateStatusItemVisibility() {
        if AppSettings.shared.showMenuBarDropzone {
            if statusItem == nil {
                createStatusItem()
            }
        } else {
            if let item = statusItem {
                NSStatusBar.system.removeStatusItem(item)
                statusItem = nil
            }
        }
    }

    private func createStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "arrow.triangle.2.circlepath.circle", accessibilityDescription: "Tossy Menu Bar Quick-Toss")
            button.imagePosition = .imageOnly
            button.toolTip = "Tossy: Drop files here to convert instantly"

            // Register for Drag and Drop
            button.registerForDraggedTypes([
                .fileURL,
                .init(UTType.image.identifier),
                .init(UTType.movie.identifier),
                .init(UTType.audio.identifier)
            ])
        }

        let menu = NSMenu()
        let titleItem = NSMenuItem(title: "Tossy Quick-Toss Zone", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)

        let hintItem = NSMenuItem(title: "Drag any file onto this icon to convert", action: nil, keyEquivalent: "")
        hintItem.isEnabled = false
        menu.addItem(hintItem)

        menu.addItem(NSMenuItem.separator())

        let openItem = NSMenuItem(title: "Open Tossy", action: #selector(openMainWindow), keyEquivalent: "o")
        openItem.target = self
        menu.addItem(openItem)

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettingsWindow), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit Tossy", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        item.menu = menu
        self.statusItem = item
    }

    @objc private func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0.canBecomeMain && !$0.isMiniaturized }) {
            window.makeKeyAndOrderFront(nil)
        } else if let window = NSApp.windows.first {
            window.deminiaturize(nil)
            window.makeKeyAndOrderFront(nil)
        }
    }

    @objc private func openSettingsWindow() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    func handleDroppedFiles(_ urls: [URL]) {
        guard !urls.isEmpty else { return }

        Task {
            let imgConverter = ImageConverter()
            let vidConverter = VideoConverter()
            let audConverter = AudioConverter()
            var convertedCount = 0

            for url in urls {
                let ext = url.pathExtension.lowercased()
                if ImageFormat.readableExtensions.contains(ext) {
                    do {
                        let res = try await imgConverter.convert(sourceURL: url, to: .webp, quality: 0.85, destinationFolder: nil)
                        convertedCount += 1
                        if AppSettings.shared.autoRevealInFinder, let firstOut = res.outputURLs.first {
                            NSWorkspace.shared.activateFileViewerSelecting([firstOut])
                        }
                    } catch {}
                } else if VideoFormat.readableExtensions.contains(ext) {
                    do {
                        let res = try await vidConverter.convert(sourceURL: url, to: .mp4H264, destinationFolder: nil) { _ in }
                        convertedCount += 1
                        if AppSettings.shared.autoRevealInFinder {
                            NSWorkspace.shared.activateFileViewerSelecting([res.outputURL])
                        }
                    } catch {}
                } else if AudioFormat.readableExtensions.contains(ext) {
                    do {
                        let res = try await audConverter.convert(sourceURL: url, to: .mp3, quality: 0.85, destinationFolder: nil) { _ in }
                        convertedCount += 1
                        if AppSettings.shared.autoRevealInFinder {
                            NSWorkspace.shared.activateFileViewerSelecting([res.outputURL])
                        }
                    } catch {}
                }
            }

            if convertedCount > 0 {
                BatchNotifier.notify(
                    summary: "Converted \(convertedCount) file\(convertedCount == 1 ? "" : "s") in background via Quick-Toss.",
                    jobCount: convertedCount
                )
            }
        }
    }
}
