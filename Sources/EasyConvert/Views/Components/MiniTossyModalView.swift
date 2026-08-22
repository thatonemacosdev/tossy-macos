import SwiftUI
import AppKit

struct MiniTossyModalView: View {
    let files: [URL]
    var initialFormat: String? = nil
    var onDismiss: () -> Void
    
    @State private var selectedCategory: FileCategory = .image
    @State private var selectedImageFormat: ImageFormat = .png
    @State private var selectedVideoFormat: VideoFormat = .mp4H264
    @State private var selectedAudioFormat: AudioFormat = .mp3
    @State private var targetSizeMB: String = ""
    
    @State private var isConverting = false
    @State private var conversionProgress: Double = 0.0
    @State private var isFinished = false
    @State private var convertedOutputs: [URL] = []
    @State private var errorMessage: String? = nil
    
    enum FileCategory: String, CaseIterable, Identifiable {
        case image = "Images"
        case video = "Video"
        case audio = "Audio"
        
        var id: String { rawValue }
        
        var icon: String {
            switch self {
            case .image: return "photo"
            case .video: return "film"
            case .audio: return "waveform"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 10) {
                Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(TossyColor.accentProminentFg)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Quick Convert with Tossy")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(TossyColor.textPrimary)
                    Text("\(files.count) \(files.count == 1 ? "item" : "items") selected from Finder")
                        .font(.caption)
                        .foregroundStyle(TossyColor.textSecondary)
                }
                
                Spacer()
                
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(TossyColor.textTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(TossyColor.surfaceDeep)
            
            Divider().overlay(TossyColor.borderSubtle)
            
            // Content
            VStack(spacing: 16) {
                if isFinished {
                    // Success View
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 44, weight: .bold))
                            .foregroundStyle(TossyColor.successGreen)
                        
                        VStack(spacing: 4) {
                            Text("Conversion Complete!")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(TossyColor.textPrimary)
                            Text("Converted \(convertedOutputs.count) \(convertedOutputs.count == 1 ? "file" : "files") successfully.")
                                .font(.caption)
                                .foregroundStyle(TossyColor.textSecondary)
                        }
                        
                        HStack(spacing: 12) {
                            if let first = convertedOutputs.first {
                                Button("Show in Finder") {
                                    NSWorkspace.shared.activateFileViewerSelecting([first])
                                }
                                .buttonStyle(.borderedProminent)
                            }
                            
                            Button("Done") {
                                onDismiss()
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(.vertical, 32)
                } else if isConverting {
                    // Converting Progress View
                    VStack(spacing: 16) {
                        ProgressView(value: conversionProgress, total: 1.0)
                            .progressViewStyle(.linear)
                            .frame(width: 260)
                        
                        Text(String(format: "Converting files… %.0f%%", conversionProgress * 100))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(TossyColor.textSecondary)
                    }
                    .padding(.vertical, 40)
                } else {
                    // File summary chip list
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(files.prefix(5), id: \.self) { file in
                                HStack(spacing: 6) {
                                    Image(systemName: iconForURL(file))
                                        .font(.system(size: 11))
                                        .foregroundStyle(TossyColor.accentProminentFg)
                                    Text(file.lastPathComponent)
                                        .font(.system(size: 11, weight: .medium))
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(TossyColor.surfaceElevated)
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            }
                            if files.count > 5 {
                                Text("+\(files.count - 5) more")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(TossyColor.textTertiary)
                                    .padding(.horizontal, 8)
                            }
                        }
                        .padding(.horizontal, 2)
                    }
                    
                    // Category Picker
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(FileCategory.allCases) { cat in
                            Label(cat.rawValue, systemImage: cat.icon).tag(cat)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    // Format Chips
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Target Format")
                            .font(.caption)
                            .foregroundStyle(TossyColor.textSecondary)
                        
                        switch selectedCategory {
                        case .image:
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                                FormatChip(title: "PNG", isSelected: selectedImageFormat == .png) { selectedImageFormat = .png }
                                FormatChip(title: "JPEG", isSelected: selectedImageFormat == .jpeg) { selectedImageFormat = .jpeg }
                                FormatChip(title: "WebP", isSelected: selectedImageFormat == .webp) { selectedImageFormat = .webp }
                                FormatChip(title: "JPEG XL", isSelected: selectedImageFormat == .jxl) { selectedImageFormat = .jxl }
                                FormatChip(title: "HEIC", isSelected: selectedImageFormat == .heic) { selectedImageFormat = .heic }
                                FormatChip(title: "GIF", isSelected: selectedImageFormat == .gif) { selectedImageFormat = .gif }
                                FormatChip(title: "AVIF", isSelected: selectedImageFormat == .avif) { selectedImageFormat = .avif }
                                FormatChip(title: "TIFF", isSelected: selectedImageFormat == .tiff) { selectedImageFormat = .tiff }
                            }
                        case .video:
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                                FormatChip(title: "MP4 (H.264)", isSelected: selectedVideoFormat == .mp4H264) { selectedVideoFormat = .mp4H264 }
                                FormatChip(title: "MP4 (HEVC)", isSelected: selectedVideoFormat == .mp4Hevc) { selectedVideoFormat = .mp4Hevc }
                                FormatChip(title: "MKV", isSelected: selectedVideoFormat == .mkv) { selectedVideoFormat = .mkv }
                                FormatChip(title: "WebM", isSelected: selectedVideoFormat == .webm) { selectedVideoFormat = .webm }
                                FormatChip(title: "GIF", isSelected: selectedVideoFormat == .animatedGif) { selectedVideoFormat = .animatedGif }
                                FormatChip(title: "ProRes", isSelected: selectedVideoFormat == .movProRes422) { selectedVideoFormat = .movProRes422 }
                            }
                        case .audio:
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                                FormatChip(title: "MP3", isSelected: selectedAudioFormat == .mp3) { selectedAudioFormat = .mp3 }
                                FormatChip(title: "FLAC", isSelected: selectedAudioFormat == .flac) { selectedAudioFormat = .flac }
                                FormatChip(title: "WAV", isSelected: selectedAudioFormat == .wav) { selectedAudioFormat = .wav }
                                FormatChip(title: "AAC / M4A", isSelected: selectedAudioFormat == .aac) { selectedAudioFormat = .aac }
                                FormatChip(title: "OGG", isSelected: selectedAudioFormat == .ogg) { selectedAudioFormat = .ogg }
                                FormatChip(title: "ALAC", isSelected: selectedAudioFormat == .alac) { selectedAudioFormat = .alac }
                            }
                        }
                    }
                    
                    // Optional Target Size
                    HStack {
                        Text("Target Size (optional):")
                            .font(.caption)
                            .foregroundStyle(TossyColor.textSecondary)
                        TextField("e.g. 25MB", text: $targetSizeMB)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 90)
                        Spacer()
                    }
                    
                    if let err = errorMessage {
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(TossyColor.errorRed)
                    }
                }
            }
            .padding(20)
            
            Divider().overlay(TossyColor.borderSubtle)
            
            // Footer Controls
            if !isFinished && !isConverting {
                HStack {
                    Button("Cancel") {
                        onDismiss()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    
                    Spacer()
                    
                    Button("Convert Now") {
                        startQuickConversion()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                    .keyboardShortcut(.defaultAction)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(TossyColor.surfaceDeep)
            }
        }
        .frame(width: 440)
        .background(TossyColor.pitchBlack)
        .onAppear {
            detectInitialCategory()
        }
    }
    
    private func detectInitialCategory() {
        guard let first = files.first else { return }
        let ext = first.pathExtension.lowercased()
        
        if VideoFormat.readableExtensions.contains(ext) {
            selectedCategory = .video
        } else if AudioFormat.readableExtensions.contains(ext) {
            selectedCategory = .audio
        } else {
            selectedCategory = .image
        }
    }
    
    private func iconForURL(_ url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        if VideoFormat.readableExtensions.contains(ext) { return "film" }
        if AudioFormat.readableExtensions.contains(ext) { return "waveform" }
        return "photo"
    }
    
    private func startQuickConversion() {
        isConverting = true
        conversionProgress = 0.1
        
        Task {
            let settings = AppSettings.shared
            var outputs: [URL] = []
            
            for (idx, file) in files.enumerated() {
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
                } catch {
                    // Ignore single failure
                }
                
                await MainActor.run {
                    conversionProgress = Double(idx + 1) / Double(files.count)
                }
            }
            
            await MainActor.run {
                self.convertedOutputs = outputs
                self.isConverting = false
                self.isFinished = true
                if settings.playCompletionSound {
                    NSSound(named: "Glass")?.play()
                }
            }
        }
    }
}

private struct FormatChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                .foregroundStyle(isSelected ? TossyColor.accentProminentFg : TossyColor.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(isSelected ? TossyColor.accentProminentBg : TossyColor.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(isSelected ? TossyColor.accentProminentBg : TossyColor.borderSubtle, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}
