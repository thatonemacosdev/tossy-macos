import SwiftUI
import AppKit

@MainActor
final class MiniTossyWindowController: NSObject, NSWindowDelegate {
    static let shared = MiniTossyWindowController()
    
    private var window: NSPanel?
    
    override private init() {
        super.init()
    }
    
    func show(with files: [URL], initialFormat: String? = nil) {
        if window == nil {
            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 440, height: 460),
                styleMask: [.titled, .closable, .fullSizeContentView, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.isFloatingPanel = true
            panel.level = .floating
            panel.titleVisibility = .hidden
            panel.titlebarAppearsTransparent = true
            panel.isMovableByWindowBackground = true
            panel.backgroundColor = .clear
            panel.delegate = self
            panel.hasShadow = true
            self.window = panel
        }
        
        guard let panel = window else { return }
        
        let miniView = MiniTossyModalView(files: files, initialFormat: initialFormat) { [weak self] in
            self?.close()
        }
        .preferredColorScheme(AppSettings.shared.appTheme == .light ? .light : .dark)
        
        panel.contentView = NSHostingView(rootView: miniView)
        panel.center()
        panel.orderFrontRegardless()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func close() {
        window?.orderOut(nil)
        window = nil
    }
    
    func windowWillClose(_ notification: Notification) {
        window = nil
    }
}
