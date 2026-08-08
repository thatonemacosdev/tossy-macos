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
        case .images: return "photo"
        case .video: return "video"
        case .audio: return "waveform"
        case .benchmark: return "speedometer"
        }
    }
}

struct RootView: View {
    @State private var selectedTab: AppTab = .images

    var body: some View {
        VStack(spacing: 0) {
            // Custom Pitch-Black Header Bar
            HStack {
                Spacer()
                HStack(spacing: 4) {
                    ForEach(AppTab.allCases) { tab in
                        TabButton(
                            tab: tab,
                            isSelected: selectedTab == tab,
                            action: { selectedTab = tab }
                        )
                    }
                }
                .padding(4)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(white: 0.10))
                )
                Spacer()
            }
            .padding(.vertical, 10)
            .background(Color.black)

            Divider()
                .overlay(Color(white: 0.18))

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
            .background(Color.black)
        }
        .preferredColorScheme(.dark)
        .tint(.white)
        .background(Color.black)
        .overlay(alignment: .bottomTrailing) {
            Text("v\(AppVersion.string)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(6)
        }
        .onAppear {
            DispatchQueue.main.async {
                for window in NSApp.windows {
                    window.backgroundColor = .black
                    window.titlebarAppearsTransparent = true
                    window.isOpaque = true
                }
            }
        }
    }
}

struct TabButton: View {
    let tab: AppTab
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: tab.icon)
                Text(tab.rawValue)
            }
            .font(.system(size: 13, weight: .medium))
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Color(white: 0.25) : (isHovered ? Color(white: 0.16) : Color.clear))
            )
            .foregroundStyle(isSelected ? Color.white : (isHovered ? Color.white : Color(white: 0.6)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
    }
}
