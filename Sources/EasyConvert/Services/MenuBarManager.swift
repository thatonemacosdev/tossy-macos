import SwiftUI
import AppKit
import UniformTypeIdentifiers

final class TossyStatusBarTrackingView: NSView {
    var onMouseEnter: (() -> Void)?
    var onMouseExit: (() -> Void)?
    var onMouseClick: ((NSEvent) -> Void)?
    var onDragEnter: (() -> Void)?
    var onDragExit: (() -> Void)?
    var onFilesDropped: (([URL]) -> Void)?
    
    private var trackingArea: NSTrackingArea?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupDragging()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupDragging()
    }

    private func setupDragging() {
        registerForDraggedTypes([
            .fileURL,
            NSPasteboard.PasteboardType(UTType.fileURL.identifier),
            NSPasteboard.PasteboardType("NSFilenamesPboardType")
        ])
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeAlways, .inVisibleRect]
        let area = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(area)
        self.trackingArea = area
    }
    
    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        onMouseEnter?()
    }
    
    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        onMouseExit?()
    }
    
    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        onMouseClick?(event)
    }
    
    override func rightMouseUp(with event: NSEvent) {
        super.rightMouseUp(with: event)
        onMouseClick?(event)
    }

    // MARK: - NSDraggingDestination

    func handleDragEntered() -> NSDragOperation {
        onDragEnter?()
        return .copy
    }

    func handleDragOperation(pasteboard: NSPasteboard) -> Bool {
        var urls: [URL] = []
        if let items = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] {
            urls = items
        }
        if urls.isEmpty, let filenames = pasteboard.propertyList(forType: NSPasteboard.PasteboardType("NSFilenamesPboardType")) as? [String] {
            urls = filenames.map { URL(fileURLWithPath: $0) }
        }
        guard !urls.isEmpty else { return false }
        onFilesDropped?(urls)
        return true
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        return handleDragEntered()
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        onDragExit?()
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        return true
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        return handleDragOperation(pasteboard: sender.draggingPasteboard)
    }
}

@MainActor
final class MenuBarManager: NSObject, ObservableObject, NSPopoverDelegate {
    static let shared = MenuBarManager()

    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var isConfigured = false
    private var closeTimer: Timer?
    private var globalMouseMonitor: Any?
    private var hoverPollingTimer: Timer?

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
            closePopoverImmediately()
        }
    }

    private func createStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "arrow.triangle.2.circlepath.circle", accessibilityDescription: "Tossy Menu Bar Quick-Toss")
            button.imagePosition = .imageOnly
            button.toolTip = "Tossy Quick-Toss: Hover or drag files to open"
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])

            // Register for Drag and Drop on button and tracking overlay
            button.registerForDraggedTypes([
                .fileURL,
                .init(UTType.fileURL.identifier),
                .init(UTType.image.identifier),
                .init(UTType.movie.identifier),
                .init(UTType.audio.identifier)
            ])
            
            // Add Hover & Drag Tracking View overlay
            let hoverOverlay = TossyStatusBarTrackingView(frame: button.bounds)
            hoverOverlay.autoresizingMask = [.width, .height]
            hoverOverlay.onMouseEnter = { [weak self] in
                self?.openPopoverIfNotShown()
            }
            hoverOverlay.onMouseExit = { [weak self] in
                self?.checkMouseHoverStatus()
            }
            hoverOverlay.onMouseClick = { [weak self] event in
                if event.type == .rightMouseUp {
                    self?.showContextMenu()
                } else {
                    self?.togglePopover()
                }
            }
            hoverOverlay.onDragEnter = { [weak self] in
                self?.cancelCloseTimer()
                self?.openPopoverIfNotShown()
            }
            hoverOverlay.onDragExit = { [weak self] in
                self?.checkMouseHoverStatus()
            }
            hoverOverlay.onFilesDropped = { [weak self] urls in
                self?.handleDroppedFiles(urls)
            }
            button.addSubview(hoverOverlay)
        }

        setupPopover()
        self.statusItem = item
    }

    private func setupPopover() {
        let pop = NSPopover()
        pop.behavior = .applicationDefined
        pop.animates = true
        pop.delegate = self

        let quickTossView = MenuBarQuickTossView(
            onOpenFullApp: { [weak self] in
                self?.closePopoverImmediately()
                self?.openMainWindow()
            },
            onOpenSettings: { [weak self] in
                self?.closePopoverImmediately()
                self?.openSettingsWindow()
            },
            onQuit: { [weak self] in
                self?.quitApp()
            }
        )

        pop.contentViewController = NSHostingController(rootView: quickTossView)
        self.popover = pop
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        togglePopover()
    }

    // MARK: - Rock-Solid Hover Lifecycle & Auto-Dismissal

    func startHoverMonitor() {
        stopHoverMonitor()

        // 1. High-frequency polling (every 80ms) for reliable bounds detection
        hoverPollingTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkMouseHoverStatus()
            }
        }

        // 2. Global mouse event monitor for instant response on mouse movement or click outside
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in
                self?.checkMouseHoverStatus()
            }
        }
    }

    func stopHoverMonitor() {
        if let monitor = globalMouseMonitor {
            NSEvent.removeMonitor(monitor)
            globalMouseMonitor = nil
        }
        hoverPollingTimer?.invalidate()
        hoverPollingTimer = nil
        cancelCloseTimer()
    }

    func checkMouseHoverStatus() {
        guard let pop = popover, pop.isShown else {
            stopHoverMonitor()
            return
        }

        // If mouse buttons are held down (active drag operation in progress!), DO NOT close the popover
        if NSEvent.pressedMouseButtons != 0 {
            cancelCloseTimer()
            return
        }

        let mouseLoc = NSEvent.mouseLocation
        var isCursorInside = false

        // 1. Check status item button screen bounds (with generous padding for gap bridging)
        if let button = statusItem?.button, let btnWindow = button.window {
            let btnScreenRect = btnWindow.convertToScreen(button.convert(button.bounds, to: nil))
            let expandedBtnRect = btnScreenRect.insetBy(dx: -16, dy: -16)
            if expandedBtnRect.contains(mouseLoc) {
                isCursorInside = true
            }
        }

        // 2. Check popover window screen bounds (with generous padding)
        if let popWindow = pop.contentViewController?.view.window {
            let popScreenRect = popWindow.frame
            let expandedPopRect = popScreenRect.insetBy(dx: -16, dy: -16)
            if expandedPopRect.contains(mouseLoc) {
                isCursorInside = true
            }
        }

        if isCursorInside {
            cancelCloseTimer()
        } else {
            // Mouse is outside both button and popover window: schedule smooth auto-close
            if closeTimer == nil {
                scheduleClose(delay: 0.35)
            }
        }
    }

    func scheduleClose(delay: TimeInterval = 0.35) {
        closeTimer?.invalidate()
        closeTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.closePopoverIfIdle()
            }
        }
    }

    func cancelCloseTimer() {
        closeTimer?.invalidate()
        closeTimer = nil
    }

    func closePopoverIfIdle() {
        guard let pop = popover, pop.isShown else {
            stopHoverMonitor()
            return
        }

        // Never close while mouse is pressed / dragged
        if NSEvent.pressedMouseButtons != 0 {
            cancelCloseTimer()
            return
        }

        let mouseLoc = NSEvent.mouseLocation

        if let button = statusItem?.button, let btnWindow = button.window {
            let btnScreenRect = btnWindow.convertToScreen(button.convert(button.bounds, to: nil))
            if btnScreenRect.insetBy(dx: -8, dy: -8).contains(mouseLoc) {
                return
            }
        }

        if let popWindow = pop.contentViewController?.view.window {
            if popWindow.frame.insetBy(dx: -8, dy: -8).contains(mouseLoc) {
                return
            }
        }

        pop.performClose(nil)
        stopHoverMonitor()
    }

    func closePopoverImmediately() {
        popover?.close()
        stopHoverMonitor()
    }

    func openPopoverIfNotShown() {
        guard let button = statusItem?.button else { return }
        if popover == nil {
            setupPopover()
        }
        if let pop = popover, !pop.isShown {
            cancelCloseTimer()
            pop.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            startHoverMonitor()
        }
    }

    func togglePopover() {
        guard let button = statusItem?.button else { return }

        if let pop = popover, pop.isShown {
            closePopoverImmediately()
        } else {
            if popover == nil {
                setupPopover()
            }
            if let pop = popover {
                cancelCloseTimer()
                pop.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                startHoverMonitor()
            }
        }
    }

    // MARK: - NSPopoverDelegate

    nonisolated func popoverDidClose(_ notification: Notification) {
        Task { @MainActor in
            self.stopHoverMonitor()
        }
    }

    private func showContextMenu() {
        guard let button = statusItem?.button else { return }
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Tossy Quick-Toss", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        
        let openItem = NSMenuItem(title: "Open Tossy", action: #selector(openMainWindow), keyEquivalent: "o")
        openItem.target = self
        menu.addItem(openItem)

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettingsWindow), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let launchOnStartupItem = NSMenuItem(title: "Launch on Startup", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchOnStartupItem.target = self
        launchOnStartupItem.state = AppSettings.shared.launchAtLogin ? .on : .off
        menu.addItem(launchOnStartupItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit Tossy", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
        button.performClick(nil)
        statusItem?.menu = nil // Reset so primary clicks open popover
    }

    @objc func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0.canBecomeMain && !$0.isMiniaturized }) {
            window.makeKeyAndOrderFront(nil)
        } else if let window = NSApp.windows.first {
            window.deminiaturize(nil)
            window.makeKeyAndOrderFront(nil)
        }
    }

    @objc func openSettingsWindow() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    @objc func toggleLaunchAtLogin() {
        AppSettings.shared.launchAtLogin.toggle()
    }

    @objc func quitApp() {
        NSApp.terminate(nil)
    }

    func handleDroppedFiles(_ urls: [URL]) {
        guard !urls.isEmpty else { return }

        openPopoverIfNotShown()

        NotificationCenter.default.post(
            name: NSNotification.Name("TossyMenuBarAddFiles"),
            object: nil,
            userInfo: ["urls": urls]
        )
    }
}
