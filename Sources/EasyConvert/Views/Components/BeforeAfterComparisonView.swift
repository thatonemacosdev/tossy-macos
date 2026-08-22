import SwiftUI
import AppKit
import AVKit
import AVFoundation

struct BeforeAfterComparisonView: View {
    let sourceURL: URL
    let outputURL: URL
    @Environment(\.dismiss) private var dismiss

    @State private var splitPosition: CGFloat = 0.5 // 0.0 ... 1.0
    @State private var comparisonMode: ComparisonMode = .split
    @State private var zoomScale: CGFloat = 1.0
    @State private var panOffset: CGSize = .zero
    @State private var isDraggingSlider = false
    @State private var showOriginalInToggle = false
    @State private var isFullscreen = false
    
    // Video Player Synchronized State
    @State private var isVideo: Bool = false
    @State private var sourcePlayer: AVPlayer?
    @State private var outputPlayer: AVPlayer?
    @State private var isPlaying: Bool = false
    @State private var currentTime: Double = 0.0
    @State private var duration: Double = 1.0
    @State private var timeObserverToken: Any?

    enum ComparisonMode: String, CaseIterable, Identifiable {
        case split = "Split Slider"
        case sideBySide = "Side by Side"
        case toggle = "A/B Toggle"

        var id: String { rawValue }
        var icon: String {
            switch self {
            case .split: return "square.split.2x1"
            case .sideBySide: return "rectangle.split.2x1"
            case .toggle: return "arrow.left.and.right.square"
            }
        }
    }

    private var sourceImage: NSImage? {
        if let img = NSImage(contentsOf: sourceURL) { return img }
        return QuickLookThumbnailGenerator.generateThumbnail(for: sourceURL, size: CGSize(width: 1200, height: 1200))
    }

    private var outputImage: NSImage? {
        if let img = NSImage(contentsOf: outputURL) { return img }
        return QuickLookThumbnailGenerator.generateThumbnail(for: outputURL, size: CGSize(width: 1200, height: 1200))
    }

    private var sourceSizeBytes: Int64 {
        (try? sourceURL.resourceValues(forKeys: [.fileSizeKey]).fileSize).flatMap { Int64($0) } ?? 0
    }

    private var outputSizeBytes: Int64 {
        (try? outputURL.resourceValues(forKeys: [.fileSizeKey]).fileSize).flatMap { Int64($0) } ?? 0
    }

    private var byteSavingsPercent: Double {
        guard sourceSizeBytes > 0 else { return 0 }
        let diff = Double(sourceSizeBytes - outputSizeBytes)
        return (diff / Double(sourceSizeBytes)) * 100.0
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            headerBar

            Divider().overlay(TossyColor.borderSubtle)

            // Main Comparison Viewport
            GeometryReader { geo in
                ZStack {
                    TossyColor.pitchBlack

                    if isVideo, let sPlayer = sourcePlayer, let oPlayer = outputPlayer {
                        videoViewportContent(sourcePlayer: sPlayer, outputPlayer: oPlayer, size: geo.size)
                    } else if let source = sourceImage, let output = outputImage {
                        viewportContent(source: source, output: output, size: geo.size)
                    } else {
                        VStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Rendering comparison frames…")
                                .font(.caption)
                                .foregroundStyle(TossyColor.textSecondary)
                        }
                    }
                }
                .clipped()
            }

            Divider().overlay(TossyColor.borderSubtle)

            // Footer Metrics & Controls
            footerBar
        }
        .frame(minWidth: isFullscreen ? 1100 : 800, minHeight: isFullscreen ? 750 : 580)
        .background(TossyColor.pitchBlack)
        .preferredColorScheme(AppSettings.shared.appTheme == .light ? .light : .dark)
        .onAppear {
            setupMedia()
        }
        .onDisappear {
            teardownPlayers()
        }
    }

    // MARK: - Media Setup
    
    private func setupMedia() {
        let videoExts = ["mp4", "mov", "m4v", "mkv", "webm", "avi"]
        let isSrcVideo = videoExts.contains(sourceURL.pathExtension.lowercased())
        let isOutVideo = videoExts.contains(outputURL.pathExtension.lowercased())
        
        if isSrcVideo || isOutVideo {
            self.isVideo = true
            let sPlayer = AVPlayer(url: sourceURL)
            let oPlayer = AVPlayer(url: outputURL)
            self.sourcePlayer = sPlayer
            self.outputPlayer = oPlayer
            
            // Get duration
            Task {
                if let asset = sPlayer.currentItem?.asset,
                   let dur = try? await asset.load(.duration) {
                    let seconds = CMTimeGetSeconds(dur)
                    if seconds.isFinite && seconds > 0 {
                        await MainActor.run {
                            self.duration = seconds
                        }
                    }
                }
            }
            
            // Sync time observer
            let interval = CMTime(seconds: 0.05, preferredTimescale: 600)
            self.timeObserverToken = sPlayer.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
                let cur = CMTimeGetSeconds(time)
                if cur.isFinite {
                    self.currentTime = cur
                }
            }
        }
    }
    
    private func teardownPlayers() {
        if let token = timeObserverToken, let sPlayer = sourcePlayer {
            sPlayer.removeTimeObserver(token)
            timeObserverToken = nil
        }
        sourcePlayer?.pause()
        outputPlayer?.pause()
        sourcePlayer = nil
        outputPlayer = nil
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(isVideo ? "Video Quality & Artifact Inspector" : "Quality & Artifact Inspector")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.white)

                Text("\(sourceURL.lastPathComponent) → \(outputURL.lastPathComponent)")
                    .font(.system(size: 11))
                    .foregroundStyle(TossyColor.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            // Mode Switcher
            Picker("Mode", selection: $comparisonMode) {
                ForEach(ComparisonMode.allCases) { mode in
                    Label(mode.rawValue, systemImage: mode.icon).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 260)

            // Zoom Controls (Images only)
            if !isVideo {
                HStack(spacing: 4) {
                    Button {
                        withAnimation(TossyMotion.springSnappy) { zoomScale = max(1.0, zoomScale - 0.5) }
                    } label: {
                        Image(systemName: "minus.magnifyingglass")
                    }
                    .disabled(zoomScale <= 1.0)

                    Text("\(Int(zoomScale * 100))%")
                        .font(.system(size: 11, design: .monospaced))
                        .frame(width: 42)

                    Button {
                        withAnimation(TossyMotion.springSnappy) { zoomScale = min(4.0, zoomScale + 0.5) }
                    } label: {
                        Image(systemName: "plus.magnifyingglass")
                    }
                    .disabled(zoomScale >= 4.0)

                    Button("1x") {
                        withAnimation(TossyMotion.springSnappy) {
                            zoomScale = 1.0
                            panOffset = .zero
                        }
                    }
                    .controlSize(.mini)
                }
                .controlSize(.small)
            }

            // Fullscreen Toggle
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    isFullscreen.toggle()
                }
            } label: {
                Image(systemName: isFullscreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
            }
            .controlSize(.small)
            .help("Toggle Fullscreen Inspection")

            Button("Done") {
                dismiss()
            }
            .controlSize(.small)
            .keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(TossyColor.surfaceBase)
    }

    // MARK: - Video Viewport Content
    
    @ViewBuilder
    private func videoViewportContent(sourcePlayer: AVPlayer, outputPlayer: AVPlayer, size: CGSize) -> some View {
        switch comparisonMode {
        case .split:
            ZStack {
                // Converted Video (Right / Background)
                VideoPlayerRepresentable(player: outputPlayer)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Original Video (Left / Masked)
                VideoPlayerRepresentable(player: sourcePlayer)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .mask(
                        GeometryReader { maskGeo in
                            Rectangle()
                                .path(in: CGRect(x: 0, y: 0, width: maskGeo.size.width * splitPosition, height: maskGeo.size.height))
                        }
                    )
                
                // Divider Line
                let splitX = size.width * splitPosition
                Rectangle()
                    .fill(Color.white)
                    .frame(width: 2)
                    .position(x: splitX, y: size.height / 2)
                    .shadow(color: Color.black.opacity(0.8), radius: 4)

                // Drag Handle
                Circle()
                    .fill(Color.white)
                    .frame(width: 28, height: 28)
                    .overlay(
                        Image(systemName: "arrow.left.and.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.black)
                    )
                    .shadow(color: Color.black.opacity(0.6), radius: 6)
                    .position(x: splitX, y: size.height / 2)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let newPos = value.location.x / size.width
                                splitPosition = max(0.02, min(0.98, newPos))
                            }
                    )
            }
            
        case .sideBySide:
            HStack(spacing: 12) {
                VStack(spacing: 6) {
                    Text("Original (\(sourceURL.pathExtension.uppercased()))")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(TossyColor.textSecondary)
                    VideoPlayerRepresentable(player: sourcePlayer)
                        .cornerRadius(8)
                }
                
                VStack(spacing: 6) {
                    Text("Converted (\(outputURL.pathExtension.uppercased()))")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(TossyColor.textSecondary)
                    VideoPlayerRepresentable(player: outputPlayer)
                        .cornerRadius(8)
                }
            }
            .padding(16)
            
        case .toggle:
            ZStack {
                if showOriginalInToggle {
                    VideoPlayerRepresentable(player: sourcePlayer)
                } else {
                    VideoPlayerRepresentable(player: outputPlayer)
                }
                
                VStack {
                    Spacer()
                    Button(showOriginalInToggle ? "Showing Original (Click for Converted)" : "Showing Converted (Click for Original)") {
                        showOriginalInToggle.toggle()
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.bottom, 20)
                }
            }
        }
    }

    // MARK: - Image Viewport Content

    @ViewBuilder
    private func viewportContent(source: NSImage, output: NSImage, size: CGSize) -> some View {
        switch comparisonMode {
        case .split:
            splitSliderView(source: source, output: output, size: size)

        case .sideBySide:
            sideBySideView(source: source, output: output, size: size)

        case .toggle:
            toggleView(source: source, output: output, size: size)
        }
    }

    // MARK: - Split Slider

    private func splitSliderView(source: NSImage, output: NSImage, size: CGSize) -> some View {
        ZStack {
            // Converted (Right / Base layer)
            Image(nsImage: output)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .scaleEffect(zoomScale)
                .offset(panOffset)

            // Original (Left / Masked layer)
            Image(nsImage: source)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .scaleEffect(zoomScale)
                .offset(panOffset)
                .mask(
                    GeometryReader { maskGeo in
                        Rectangle()
                            .path(in: CGRect(x: 0, y: 0, width: maskGeo.size.width * splitPosition, height: maskGeo.size.height))
                    }
                )

            // Divider Line & Handle
            let splitX = size.width * splitPosition
            Rectangle()
                .fill(Color.white)
                .frame(width: 2)
                .position(x: splitX, y: size.height / 2)
                .shadow(color: Color.black.opacity(0.8), radius: 4)

            // Floating Handle Grabber
            Circle()
                .fill(Color.white)
                .frame(width: 28, height: 28)
                .overlay(
                    Image(systemName: "arrow.left.and.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.black)
                )
                .shadow(color: Color.black.opacity(0.6), radius: 6)
                .position(x: splitX, y: size.height / 2)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            let newPos = value.location.x / size.width
                            splitPosition = max(0.02, min(0.98, newPos))
                        }
                )

            // Floating Badges
            VStack {
                HStack {
                    Text("Original (\(sourceURL.pathExtension.uppercased()))")
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.7))
                        .clipShape(Capsule())
                        .padding(12)

                    Spacer()

                    Text("Converted (\(outputURL.pathExtension.uppercased()))")
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.7))
                        .clipShape(Capsule())
                        .padding(12)
                }
                Spacer()
            }
        }
        .gesture(
            DragGesture()
                .onChanged { val in
                    if zoomScale > 1.0 {
                        panOffset = CGSize(width: panOffset.width + val.translation.width * 0.1, height: panOffset.height + val.translation.height * 0.1)
                    }
                }
        )
    }

    // MARK: - Side by Side View

    private func sideBySideView(source: NSImage, output: NSImage, size: CGSize) -> some View {
        HStack(spacing: 12) {
            VStack(spacing: 6) {
                Text("Original")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(TossyColor.textSecondary)

                Image(nsImage: source)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(zoomScale)
                    .offset(panOffset)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(TossyColor.surfaceBase)
                    .cornerRadius(8)
            }

            VStack(spacing: 6) {
                Text("Converted")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(TossyColor.textSecondary)

                Image(nsImage: output)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(zoomScale)
                    .offset(panOffset)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(TossyColor.surfaceBase)
                    .cornerRadius(8)
            }
        }
        .padding(16)
    }

    // MARK: - A/B Toggle View

    private func toggleView(source: NSImage, output: NSImage, size: CGSize) -> some View {
        ZStack {
            Image(nsImage: showOriginalInToggle ? source : output)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .scaleEffect(zoomScale)
                .offset(panOffset)

            VStack {
                Spacer()
                Button(showOriginalInToggle ? "Showing Original (Click for Converted)" : "Showing Converted (Click for Original)") {
                    showOriginalInToggle.toggle()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .padding(.bottom, 20)
            }
        }
    }

    // MARK: - Footer Metrics Bar

    private var footerBar: some View {
        VStack(spacing: 8) {
            // Video Playhead Controls (when comparing videos)
            if isVideo {
                HStack(spacing: 12) {
                    Button {
                        toggleVideoPlayback()
                    } label: {
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 14))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.white)
                    
                    Text(formatTime(currentTime))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(TossyColor.textSecondary)
                    
                    Slider(value: Binding(
                        get: { currentTime },
                        set: { seekVideos(to: $0) }
                    ), in: 0...max(0.1, duration))
                    
                    Text(formatTime(duration))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(TossyColor.textSecondary)
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
            }
            
            HStack(spacing: 20) {
                // Source Info
                HStack(spacing: 8) {
                    Text("Source:")
                        .font(.caption)
                        .foregroundStyle(TossyColor.textTertiary)
                    Text(ByteSize.displayString(sourceSizeBytes))
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color.white)
                }

                // Arrow
                Image(systemName: "arrow.right")
                    .font(.system(size: 11))
                    .foregroundStyle(TossyColor.textTertiary)

                // Output Info
                HStack(spacing: 8) {
                    Text("Output:")
                        .font(.caption)
                        .foregroundStyle(TossyColor.textTertiary)
                    Text(ByteSize.displayString(outputSizeBytes))
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color.white)
                }

                // Savings Pill
                if sourceSizeBytes > outputSizeBytes {
                    Text("Saved \(ByteSize.displayString(sourceSizeBytes - outputSizeBytes)) (-\(String(format: "%.1f", byteSavingsPercent))%)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(TossyColor.successGreen)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(TossyColor.successGreen.opacity(0.15))
                        .clipShape(Capsule())
                }

                Spacer()

                // Quick Actions
                HStack(spacing: 10) {
                    Button("Reveal in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([outputURL])
                    }
                    .controlSize(.small)

                    Button("Open") {
                        NSWorkspace.shared.open(outputURL)
                    }
                    .controlSize(.small)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 10)
        }
        .background(TossyColor.surfaceBase)
    }
    
    private func toggleVideoPlayback() {
        if isPlaying {
            sourcePlayer?.pause()
            outputPlayer?.pause()
            isPlaying = false
        } else {
            sourcePlayer?.play()
            outputPlayer?.play()
            isPlaying = true
        }
    }
    
    private func seekVideos(to seconds: Double) {
        let time = CMTime(seconds: seconds, preferredTimescale: 600)
        sourcePlayer?.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
        outputPlayer?.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
        currentTime = seconds
    }
    
    private func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}

// MARK: - Native macOS Video Player NSViewRepresentable

struct VideoPlayerRepresentable: NSViewRepresentable {
    let player: AVPlayer
    
    func makeNSView(context: Context) -> AVPlayerView {
        let playerView = AVPlayerView()
        playerView.player = player
        playerView.controlsStyle = .none
        playerView.showsFullScreenToggleButton = false
        return playerView
    }
    
    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        nsView.player = player
    }
}

// MARK: - QuickLook Fallback Generator

enum QuickLookThumbnailGenerator {
    static func generateThumbnail(for url: URL, size: CGSize) -> NSImage? {
        if let image = NSImage(contentsOf: url) { return image }
        return NSWorkspace.shared.icon(forFile: url.path)
    }
}
