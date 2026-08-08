import SwiftUI
import AppKit

struct RootView: View {
    var body: some View {
        TabView {
            ContentView()
                .tabItem { Label("Images", systemImage: "photo") }

            VideoConvertView()
                .tabItem { Label("Video", systemImage: "video") }

            AudioConvertView()
                .tabItem { Label("Audio", systemImage: "waveform") }

            BenchmarkView()
                .tabItem { Label("Benchmark", systemImage: "speedometer") }
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
                    window.isOpaque = true
                }
            }
        }
    }
}
