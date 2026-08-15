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

    var body: some View {
        VStack(spacing: 0) {
            // Pitch-Black Header Bar
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
                            .foregroundStyle(Color.white)
                    }
                    
                    Text("Tossy")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.white)
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
                .padding(.trailing, 14)
            }
            .padding(.vertical, 8)
            .background(TossyColor.pitchBlack)

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
            .background(TossyColor.pitchBlack)
        }
        .preferredColorScheme(.dark)
        .tint(.white)
        .background(TossyColor.pitchBlack)
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
            .foregroundStyle(isSelected ? Color.black : (isHovered ? Color.white : TossyColor.textSecondary))
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.white)
                        .matchedGeometryEffect(id: "activeTabCapsule", in: namespace)
                        .shadow(color: Color.white.opacity(0.2), radius: 6)
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
