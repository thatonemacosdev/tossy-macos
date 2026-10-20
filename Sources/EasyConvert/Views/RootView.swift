import SwiftUI
import AppKit
import UniformTypeIdentifiers

enum AppTab: String, CaseIterable, Identifiable {
    case dropzone = "Dropzone"
    case images = "Images"
    case video = "Video"
    case audio = "Audio"
    case benchmark = "Benchmark"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .dropzone: return "arrow.triangle.2.circlepath.circle"
        case .images: return "photo.stack"
        case .video: return "video"
        case .audio: return "waveform"
        case .benchmark: return "speedometer"
        }
    }
}

struct RootView: View {
    @State private var selectedTab: AppTab = .dropzone
    @Namespace private var tabNamespace
    @Environment(\.openSettings) private var openSettingsAction
    @Bindable var settings = AppSettings.shared
    @State private var isHeaderTargeted: Bool = false
    @State private var showWhatsNew: Bool = false

    private var visibleTabs: [AppTab] {
        if settings.navigationLayoutMode == .classic {
            return [.dropzone, .images, .video, .audio, .benchmark]
        } else {
            return [.dropzone, .benchmark]
        }
    }

    var body: some View {
        ZStack {
            // Background Layer
            if settings.appTheme == .liquidGlass {
                VisualEffectBackground(material: .hudWindow, blendingMode: .behindWindow)
                Color.black.opacity(0.28)
            } else if settings.appTheme == .titanium {
                BrushedTitaniumBackground()
            } else {
                TossyColor.pitchBlack
            }

            VStack(spacing: 0) {
                // Header Bar
                HStack {
                    // App Logo / Title
                    HStack(spacing: 8) {
                        if let logoURL = Bundle.main.url(forResource: "TossyLogo", withExtension: "png"),
                           let nsImg = NSImage(contentsOf: logoURL) {
                            Image(nsImage: nsImg)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 18, height: 18)
                                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                        } else if let icon = NSApp.applicationIconImage {
                            Image(nsImage: icon)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 18, height: 18)
                                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                        } else {
                            Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(TossyColor.textPrimary)
                        }

                        Text("Tossy")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(TossyColor.textPrimary)
                    }
                    .padding(.leading, 14)

                    Spacer()

                    // Sliding Capsule Tab Bar
                    HStack(spacing: 4) {
                        ForEach(visibleTabs) { tab in
                            SlidingTabButton(
                                tab: tab,
                                isSelected: selectedTab == tab,
                                namespace: tabNamespace,
                                action: {
                                    withAnimation(TossyMotion.springSmooth) {
                                        selectedTab = tab
                                    }
                                }
                            )
                        }
                    }
                    .padding(4)
                    .background(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .fill(TossyColor.surfaceDeep)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .strokeBorder(isHeaderTargeted ? Color.accentColor : TossyColor.borderSubtle, lineWidth: 1)
                    )
                    .onDrop(of: [.fileURL], isTargeted: $isHeaderTargeted) { providers in
                        routeDroppedProviders(providers)
                        return true
                    }

                    Spacer()

                    HStack(spacing: 8) {
                        // Quick Layout Switcher (Unified vs Classic Tabs)
                        Button {
                            withAnimation(TossyMotion.springSmooth) {
                                settings.navigationLayoutMode = (settings.navigationLayoutMode == .unified) ? .classic : .unified
                                if settings.navigationLayoutMode == .unified && selectedTab != .benchmark {
                                    selectedTab = .dropzone
                                }
                            }
                        } label: {
                            Image(systemName: settings.navigationLayoutMode == .unified ? "rectangle.split.3x1" : "rectangle.stack")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(TossyColor.textSecondary)
                                .padding(6)
                                .background(Circle().fill(TossyColor.surfaceElevated))
                        }
                        .buttonStyle(.plain)
                        .help(settings.navigationLayoutMode == .unified ? "Switch to Classic Tabs Layout" : "Switch to Unified Dropzone Layout")

                        // High-Resolution Recording & UI Scale Switcher
                        Menu {
                            ForEach(RecordingScaleMode.allCases) { scaleMode in
                                Button {
                                    withAnimation(TossyMotion.springSmooth) {
                                        settings.recordingScaleMode = scaleMode
                                    }
                                } label: {
                                    HStack {
                                        Text(scaleMode.rawValue)
                                        if settings.recordingScaleMode == scaleMode {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            Image(systemName: "viewfinder.circle")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(
                                    settings.recordingScaleMode != .responsive && settings.recordingScaleMode != .standard ?
                                    TossyColor.accentProminentBg : TossyColor.textSecondary
                                )
                                .padding(6)
                                .background(Circle().fill(TossyColor.surfaceElevated))
                        }
                        .menuStyle(.borderlessButton)
                        .menuIndicator(.hidden)
                        .frame(width: 26, height: 26)
                        .help("Recording & Display Scale (\(settings.recordingScaleMode.rawValue))")

                        // Quick Theme Switcher
                        Menu {
                            ForEach(AppTheme.allCases) { theme in
                                Button {
                                    withAnimation(TossyMotion.springSmooth) {
                                        settings.appTheme = theme
                                    }
                                } label: {
                                    HStack {
                                        Label(theme.rawValue, systemImage: theme.icon)
                                        if settings.appTheme == theme {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            Image(systemName: settings.appTheme.icon)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(TossyColor.textSecondary)
                                .padding(6)
                                .background(Circle().fill(TossyColor.surfaceElevated))
                        }
                        .menuStyle(.borderlessButton)
                        .menuIndicator(.hidden)
                        .frame(width: 26, height: 26)
                        .help("Change Theme Appearance (Dark / Light / Liquid Glass / Titanium)")

                        // Settings Button (Cmd+,)
                        Button {
                            openSettings()
                        } label: {
                            Image(systemName: "gearshape")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(TossyColor.textSecondary)
                                .padding(6)
                                .background(Circle().fill(TossyColor.surfaceElevated))
                        }
                        .buttonStyle(.plain)
                        .help("Settings (Cmd+,)")
                    }
                    .padding(.trailing, 14)
                }
                .padding(.vertical, 8)
                .background(
                    settings.appTheme == .liquidGlass ? Color.black.opacity(0.15) :
                    (settings.appTheme == .titanium ? Color.black.opacity(0.22) : TossyColor.pitchBlack)
                )

                Divider()
                    .overlay(TossyColor.borderSubtle)

                // Active Tab View
                Group {
                    switch selectedTab {
                    case .dropzone: UniversalCanvasView()
                    case .images: ContentView()
                    case .video: VideoConvertView()
                    case .audio: AudioConvertView()
                    case .benchmark: BenchmarkView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .scaleEffect(
                    settings.recordingScaleMode == .responsive ? 1.0 : settings.recordingScaleMode.baseMultiplier,
                    anchor: .center
                )
                .animation(TossyMotion.springSmooth, value: settings.recordingScaleMode)
                .background(
                    settings.appTheme == .liquidGlass || settings.appTheme == .titanium ? Color.clear : TossyColor.pitchBlack
                )
            }
        }
        .preferredColorScheme(settings.appTheme == .light ? .light : .dark)
        .tint(TossyColor.accentProminentBg)
        .overlay(alignment: .bottomTrailing) {
            Text("v\(AppVersion.string)")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(TossyColor.textTertiary)
                .padding(6)
        }
        .sheet(isPresented: Bindable(UpdateManager.shared).isShowingUpdateModal) {
            if let release = UpdateManager.shared.availableUpdate {
                UpdateModalView(release: release)
            }
        }
        .sheet(isPresented: $showWhatsNew) {
            WhatsNewModalView()
        }
        .onAppear {
            if AppSettings.shared.lastSeenWhatsNewVersion != AppVersion.string {
                AppSettings.shared.lastSeenWhatsNewVersion = AppVersion.string
                showWhatsNew = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TossyShowWhatsNew"))) { _ in
            showWhatsNew = true
        }
    }

    private func openSettings() {
        openSettingsAction()
    }
    
    private func routeDroppedProviders(_ providers: [NSItemProvider]) {
        Task { @MainActor in
            let collected = await FileDropResolver.resolveURLs(from: providers)
            guard !collected.isEmpty else { return }
            
            if let first = collected.first, CodeLanguageDetector.codeExtensions.contains(first.pathExtension.lowercased()) {
                withAnimation(TossyMotion.springSmooth) {
                    self.selectedTab = .dropzone
                }
                NotificationCenter.default.post(
                    name: NSNotification.Name("TossyOpenCodeCard"),
                    object: nil,
                    userInfo: ["url": first]
                )
                return
            }
            
            withAnimation(TossyMotion.springSmooth) {
                if settings.navigationLayoutMode == .classic, let first = collected.first {
                    let ext = first.pathExtension.lowercased()
                    if ["mov", "mp4", "m4v", "mkv", "webm", "avi", "flv", "wmv", "ts"].contains(ext) {
                        self.selectedTab = .video
                    } else if ["mp3", "m4a", "wav", "flac", "aac", "ogg", "aiff", "wma", "opus", "alac", "weba"].contains(ext) {
                        self.selectedTab = .audio
                    } else if ["png", "jpg", "jpeg", "heic", "webp", "gif", "svg", "jxl", "avif", "tiff"].contains(ext) {
                        self.selectedTab = .images
                    } else {
                        self.selectedTab = .dropzone
                    }
                } else {
                    self.selectedTab = .dropzone
                }
            }
            NotificationCenter.default.post(
                name: NSNotification.Name("TossyDropFiles"),
                object: nil,
                userInfo: ["urls": collected]
            )
        }
    }
}

struct SlidingTabButton: View {
    let tab: AppTab
    let isSelected: Bool
    var namespace: Namespace.ID
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: tab.icon)
                    .font(.system(size: 12, weight: .medium))
                Text(tab.rawValue)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .foregroundStyle(isSelected ? TossyColor.accentProminentFg : (isHovered ? TossyColor.textPrimary : TossyColor.textSecondary))
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(TossyColor.accentProminentBg)
                        .matchedGeometryEffect(id: "activeTabCapsule", in: namespace)
                        .shadow(color: TossyColor.accentProminentBg.opacity(0.2), radius: 6)
                } else if isHovered {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(TossyColor.surfaceHighlight)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
