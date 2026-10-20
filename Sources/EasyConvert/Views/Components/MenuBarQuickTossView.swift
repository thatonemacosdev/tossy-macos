import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct MenuBarQuickTossView: View {
    var onOpenFullApp: () -> Void
    var onOpenSettings: () -> Void
    var onQuit: () -> Void
    
    @State private var droppedURLs: [URL] = []
    @State private var isTargeted = false
    @State private var selectedCategory: QuickCategory = .image
    @State private var selectedImageFormat: ImageFormat = .webp
    @State private var selectedVideoFormat: VideoFormat = .mp4H264
    @State private var selectedAudioFormat: AudioFormat = .mp3
    
    @State private var isConverting = false
    @State private var conversionProgress: Double = 0.0
    @State private var completedOutputs: [URL] = []
    
    enum QuickCategory: String, CaseIterable, Identifiable {
        case image = "Image"
        case video = "Video"
        case audio = "Audio"
        
        var id: String { rawValue }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Popover Header
            HStack(spacing: 8) {
                Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(TossyColor.accentProminentFg)
                
                Text("Quick-Toss")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(TossyColor.textPrimary)
                
                Spacer()
                
                Picker("", selection: $selectedCategory) {
                    ForEach(QuickCategory.allCases) { cat in
                        Text(cat.rawValue).tag(cat)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 150)
                
                Button {
                    MenuBarManager.shared.togglePopover()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(TossyColor.textTertiary)
                }
                .buttonStyle(.plain)
                .help("Close Popover")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(TossyColor.surfaceDeep)
            
            Divider().overlay(TossyColor.borderSubtle)
            
            // Main Drop Area / Active Conversion
            VStack(spacing: 10) {
                if !completedOutputs.isEmpty {
                    // Success View
                    VStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(TossyColor.successGreen)
                        
                        Text("Converted \(completedOutputs.count) file(s)!")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(TossyColor.textPrimary)
                        
                        HStack(spacing: 8) {
                            Button("Show in Finder") {
                                NSWorkspace.shared.activateFileViewerSelecting(completedOutputs)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            
                            Button("Convert More") {
                                withAnimation {
                                    droppedURLs.removeAll()
                                    completedOutputs.removeAll()
                                }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                    .padding(.vertical, 20)
                } else if isConverting {
                    // Progress View
                    VStack(spacing: 10) {
                        ProgressView(value: conversionProgress, total: 1.0)
                            .progressViewStyle(.linear)
                            .frame(width: 220)
                        
                        Text("Converting… \(Int(conversionProgress * 100))%")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(TossyColor.textSecondary)
                    }
                    .padding(.vertical, 26)
                } else if droppedURLs.isEmpty {
                    // Empty Drop Target
                    VStack(spacing: 8) {
                        Image(systemName: isTargeted ? "arrow.down.circle.fill" : "plus.rectangle.on.rectangle")
                            .font(.system(size: 28))
                            .foregroundStyle(isTargeted ? TossyColor.accentProminentFg : TossyColor.textTertiary)
                        
                        Text("Drop files here to convert")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(TossyColor.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(isTargeted ? TossyColor.accentProminentBg : TossyColor.borderSubtle, style: StrokeStyle(lineWidth: 1.5, dash: [5]))
                    )
                    .padding(.horizontal, 12)
                    .padding(.top, 10)
                } else {
                    // Queued Files List
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("\(droppedURLs.count) file(s) queued")
                                .font(.caption.bold())
                                .foregroundStyle(TossyColor.textSecondary)
                            Spacer()
                            Button("Clear") {
                                droppedURLs.removeAll()
                            }
                            .buttonStyle(.plain)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        }
                        
                        ForEach(droppedURLs.prefix(3), id: \.self) { url in
                            HStack(spacing: 6) {
                                Image(systemName: "doc.fill")
                                    .font(.caption2)
                                    .foregroundStyle(TossyColor.accentProminentFg)
                                Text(url.lastPathComponent)
                                    .font(.system(size: 11))
                                    .lineLimit(1)
                                Spacer()
                            }
                            .padding(4)
                            .background(RoundedRectangle(cornerRadius: 4).fill(TossyColor.surfaceElevated))
                        }
                        if droppedURLs.count > 3 {
                            Text("+\(droppedURLs.count - 3) more")
                                .font(.caption2)
                                .foregroundStyle(TossyColor.textTertiary)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 6)
                }
                
                // Format Selector Chips
                if !isConverting && completedOutputs.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Convert to:")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(TossyColor.textTertiary)
                            .padding(.horizontal, 12)
                        
                        switch selectedCategory {
                        case .image:
                            HStack(spacing: 6) {
                                formatChip("WebP", isSelected: selectedImageFormat == .webp) { selectedImageFormat = .webp }
                                formatChip("PNG", isSelected: selectedImageFormat == .png) { selectedImageFormat = .png }
                                formatChip("JPEG", isSelected: selectedImageFormat == .jpeg) { selectedImageFormat = .jpeg }
                                formatChip("JXL", isSelected: selectedImageFormat == .jxl) { selectedImageFormat = .jxl }
                            }
                            .padding(.horizontal, 12)
                        case .video:
                            HStack(spacing: 6) {
                                formatChip("MP4", isSelected: selectedVideoFormat == .mp4H264) { selectedVideoFormat = .mp4H264 }
                                formatChip("WebM", isSelected: selectedVideoFormat == .webm) { selectedVideoFormat = .webm }
                                formatChip("GIF", isSelected: selectedVideoFormat == .animatedGif) { selectedVideoFormat = .animatedGif }
                                formatChip("MKV", isSelected: selectedVideoFormat == .mkv) { selectedVideoFormat = .mkv }
                            }
                            .padding(.horizontal, 12)
                        case .audio:
                            HStack(spacing: 6) {
                                formatChip("MP3", isSelected: selectedAudioFormat == .mp3) { selectedAudioFormat = .mp3 }
                                formatChip("AAC", isSelected: selectedAudioFormat == .aac) { selectedAudioFormat = .aac }
                                formatChip("FLAC", isSelected: selectedAudioFormat == .flac) { selectedAudioFormat = .flac }
                                formatChip("WAV", isSelected: selectedAudioFormat == .wav) { selectedAudioFormat = .wav }
                            }
                            .padding(.horizontal, 12)
                        }
                        
                        if !droppedURLs.isEmpty {
                            Button {
                                startConversion()
                            } label: {
                                Text("Convert Now")
                                    .font(.system(size: 12, weight: .bold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 6)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            .padding(.horizontal, 12)
                            .padding(.top, 4)
                        }
                    }
                }
            }
            .padding(.bottom, 10)
            .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
                handleDrop(providers)
                return true
            }
            
            Divider().overlay(TossyColor.borderSubtle)
            
            // Popover Footer Actions
            HStack {
                Button("Open App") {
                    onOpenFullApp()
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(TossyColor.textSecondary)
                
                Spacer()
                
                Button("Settings…") {
                    onOpenSettings()
                }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundStyle(TossyColor.textTertiary)
                
                Spacer()
                
                Button("Quit") {
                    onQuit()
                }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundStyle(TossyColor.textTertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(TossyColor.surfaceDeep)
        }
        .frame(width: 320)
        .background(TossyColor.pitchBlack)
        .preferredColorScheme(AppSettings.shared.appTheme == .light ? .light : .dark)
        .onHover { isHovering in
            if isHovering {
                MenuBarManager.shared.cancelCloseTimer()
            } else {
                MenuBarManager.shared.scheduleClose(delay: 0.35)
            }
        }
        .onChange(of: isTargeted) { targeted in
            if targeted {
                MenuBarManager.shared.cancelCloseTimer()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TossyMenuBarAddFiles"))) { notif in
            if let urls = notif.userInfo?["urls"] as? [URL], !urls.isEmpty {
                if !completedOutputs.isEmpty {
                    completedOutputs.removeAll()
                }
                for u in urls where !droppedURLs.contains(u) {
                    droppedURLs.append(u)
                }
                if let first = urls.first {
                    let ext = first.pathExtension.lowercased()
                    if VideoFormat.readableExtensions.contains(ext) {
                        self.selectedCategory = .video
                    } else if AudioFormat.readableExtensions.contains(ext) {
                        self.selectedCategory = .audio
                    } else {
                        self.selectedCategory = .image
                    }
                }
            }
        }
    }
    
    private func formatChip(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                .foregroundStyle(isSelected ? TossyColor.accentProminentFg : TossyColor.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
                .background(isSelected ? TossyColor.accentProminentBg : TossyColor.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
    }
    
    private func handleDrop(_ providers: [NSItemProvider]) {
        Task { @MainActor in
            let urls = await FileDropResolver.resolveURLs(from: providers)
            for url in urls where !self.droppedURLs.contains(url) {
                self.droppedURLs.append(url)
            }
            if let first = urls.first {
                let ext = first.pathExtension.lowercased()
                if VideoFormat.readableExtensions.contains(ext) {
                    if let probe = MediaProbe.probe(url: first), !probe.hasVideo && probe.hasAudio {
                        self.selectedCategory = .audio
                    } else {
                        self.selectedCategory = .video
                    }
                } else if AudioFormat.readableExtensions.contains(ext) {
                    self.selectedCategory = .audio
                } else {
                    self.selectedCategory = .image
                }
            }
        }
    }
    
    private func startConversion() {
        guard !droppedURLs.isEmpty else { return }
        isConverting = true
        conversionProgress = 0.1
        
        Task {
            let settings = AppSettings.shared
            var outputs: [URL] = []
            
            for (idx, file) in droppedURLs.enumerated() {
                let dest = settings.destinationFolder(for: file)
                do {
                    switch selectedCategory {
                    case .image:
                        let res = try await ImageConverter().convert(sourceURL: file, to: selectedImageFormat, destinationFolder: dest)
                        outputs.append(contentsOf: res.outputURLs)
                    case .video:
                        let res = try await VideoConverter().convert(sourceURL: file, to: selectedVideoFormat, destinationFolder: dest, onProgress: { _ in })
                        outputs.append(res.outputURL)
                    case .audio:
                        let res = try await AudioConverter().convert(sourceURL: file, to: selectedAudioFormat, destinationFolder: dest, onProgress: { _ in })
                        outputs.append(res.outputURL)
                    }
                } catch {}
                
                await MainActor.run {
                    self.conversionProgress = Double(idx + 1) / Double(droppedURLs.count)
                }
            }
            
            await MainActor.run {
                self.completedOutputs = outputs
                self.isConverting = false
                if settings.playCompletionSound {
                    NSSound(named: "Glass")?.play()
                }
            }
        }
    }
}
