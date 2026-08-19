import SwiftUI
import AppKit

enum AppTab: String, CaseIterable, Identifiable {
    case images = "Images"
    case video = "Video"
    case audio = "Audio"
    case benchmark = "Benchmark"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .images: return "photo.stack"
        case .video: return "video"
        case .audio: return "waveform"
        case .benchmark: return "speedometer"
        }
    }
}

struct RootView: View {
    @State private var selectedTab: AppTab = .images
    @Namespace private var tabNamespace
    @Environment(\.openSettings) private var openSettingsAction
    @Bindable var settings = AppSettings.shared

    var body: some View {
        ZStack {
            // Background Layer
            if settings.appTheme == .liquidGlass {
                VisualEffectBackground(material: .hudWindow, blendingMode: .behindWindow)
                Color.black.opacity(0.28)
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
                        ForEach(AppTab.allCases) { tab in
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
                            .strokeBorder(TossyColor.borderSubtle, lineWidth: 1)
                    )

                    Spacer()

                    HStack(spacing: 8) {
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
                        .help("Change Theme Appearance (Dark / Light / Liquid Glass)")

                        // Settings Button (⌘,)
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
                        .help("Settings (⌘,)")
                    }
                    .padding(.trailing, 14)
                }
                .padding(.vertical, 8)
                .background(settings.appTheme == .liquidGlass ? Color.black.opacity(0.15) : TossyColor.pitchBlack)

                Divider()
                    .overlay(TossyColor.borderSubtle)

                // Active Tab View
                Group {
                    switch selectedTab {
                    case .images: ContentView()
                    case .video: VideoConvertView()
                    case .audio: AudioConvertView()
                    case .benchmark: BenchmarkView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(settings.appTheme == .liquidGlass ? Color.clear : TossyColor.pitchBlack)
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
    }

    private func openSettings() {
        openSettingsAction()
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
