import SwiftUI

struct MediaStudioModalView: View {
    let sourceURLs: [URL]
    var initialTab: MediaStudioTab = .trim
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedTab: MediaStudioTab
    
    init(sourceURLs: [URL], initialTab: MediaStudioTab = .trim) {
        self.sourceURLs = sourceURLs
        self.initialTab = initialTab
        self._selectedTab = State(initialValue: initialTab)
    }
    @State private var isProcessing = false
    @State private var statusMessage: String?
    @State private var outputURL: URL?
    @State private var showingComparison = false
    
    // Trim state
    @State private var trimStartText: String = "0.0"
    @State private var trimEndText: String = "10.0"
    
    // Audio state
    @State private var audioFormat: AudioFormat = .mp3
    
    // Rotate/Speed state
    @State private var rotationDegrees: Int = 0
    @State private var flipHorizontal: Bool = false
    @State private var flipVertical: Bool = false
    @State private var speedMultiplier: Double = 1.0 // Default 1.00x baseline
    
    // Watermark state
    @State private var watermarkText: String = "CONFIDENTIAL"
    @State private var watermarkAnchor: WatermarkAnchor = .bottomRight
    @State private var watermarkOpacity: Double = 0.70
    @State private var watermarkFontSize: Double = 28.0
    
    enum MediaStudioTab: String, CaseIterable, Identifiable {
        case trim = "Lossless Trim"
        case extractAudio = "Extract Audio"
        case stripAudio = "Mute / Strip"
        case rotateSpeed = "Rotate & Speed"
        case watermark = "Watermark"
        case removeBg = "Remove BG"
        
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .trim: return "timeline.selection"
            case .extractAudio: return "waveform"
            case .stripAudio: return "speaker.slash.fill"
            case .rotateSpeed: return "rotate.right"
            case .watermark: return "character.cursor.ibeam"
            case .removeBg: return "person.and.background.dotted"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "film.stack")
                    .font(.title2)
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Media Studio Tools")
                        .font(.headline)
                    Text("\(sourceURLs.count) file(s) selected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(nsColor: .windowBackgroundColor))
            
            Divider()
            
            // Mode Selector
            Picker("", selection: $selectedTab) {
                ForEach(MediaStudioTab.allCases) { tab in
                    Label(tab.rawValue, systemImage: tab.icon).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding()
            
            // Tab Content
            ScrollView {
                VStack(spacing: 16) {
                    switch selectedTab {
                    case .trim:
                        trimView
                    case .extractAudio:
                        extractAudioView
                    case .stripAudio:
                        stripAudioView
                    case .rotateSpeed:
                        rotateSpeedView
                    case .watermark:
                        watermarkView
                    case .removeBg:
                        removeBgView
                    }
                }
                .padding(.horizontal)
            }
            
            Divider()
            
            // Footer
            HStack {
                if isProcessing {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Processing with Metal / FFmpeg engine...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if let statusMessage {
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                if let outputURL {
                    Button("Compare Side-by-Side") {
                        showingComparison = true
                    }
                    .buttonStyle(.bordered)
                    .help("Open interactive side-by-side split comparison")

                    Button("Show in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([outputURL])
                    }
                    .buttonStyle(.bordered)
                }
                
                Button(actionButtonTitle) {
                    executeAction()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isProcessing || sourceURLs.isEmpty)
            }
            .padding()
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(minWidth: 700, minHeight: 520)
        .sheet(isPresented: $showingComparison) {
            if let src = sourceURLs.first, let out = outputURL {
                BeforeAfterComparisonView(sourceURL: src, outputURL: out)
            }
        }
    }
    
    private var actionButtonTitle: String {
        switch selectedTab {
        case .trim: return "Trim Video (Lossless)"
        case .extractAudio: return "Extract Audio Track"
        case .stripAudio: return "Strip Audio (Mute)"
        case .rotateSpeed: return "Apply Transform"
        case .watermark: return "Apply Watermark"
        case .removeBg: return "Isolate Subject & Remove BG"
        }
    }
    
    private var trimView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Losslessly trim video without re-encoding in milliseconds:")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Start (seconds):").font(.caption).foregroundStyle(.secondary)
                    TextField("0.0", text: $trimStartText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 120)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("End (seconds):").font(.caption).foregroundStyle(.secondary)
                    TextField("10.0", text: $trimEndText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 120)
                }
            }
        }
    }
    
    private var extractAudioView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Extract high-bitrate audio track from video:")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Picker("Audio Format", selection: $audioFormat) {
                Text("MP3 (320 kbps)").tag(AudioFormat.mp3)
                Text("AAC (256 kbps)").tag(AudioFormat.aac)
                Text("FLAC (Lossless)").tag(AudioFormat.flac)
                Text("WAV (Uncompressed)").tag(AudioFormat.wav)
            }
            .pickerStyle(.radioGroup)
        }
    }
    
    private var stripAudioView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Remove all audio tracks from the video stream with zero video quality loss.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
    
    private var rotateSpeedView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Video Geometry & Playback Speed:")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Picker("Rotation", selection: $rotationDegrees) {
                Text("No Rotation (0 degrees)").tag(0)
                Text("90 degrees Clockwise").tag(90)
                Text("180 degrees").tag(180)
                Text("270 degrees (90 degrees CCW)").tag(270)
            }
            
            HStack(spacing: 20) {
                Toggle("Flip Horizontally (Mirror)", isOn: $flipHorizontal)
                    .toggleStyle(.checkbox)
                Toggle("Flip Vertically", isOn: $flipVertical)
                    .toggleStyle(.checkbox)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Speed Multiplier: \(String(format: "%.2f", speedMultiplier))x")
                        .font(.body.monospacedDigit())
                    Spacer()
                    if abs(speedMultiplier - 1.0) > 0.01 {
                        Button("Reset to 1.00x") {
                            speedMultiplier = 1.00
                        }
                        .controlSize(.mini)
                    }
                }
                Slider(value: $speedMultiplier, in: 0.25...4.0, step: 0.25)
            }
        }
    }
    
    private var watermarkView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Universal Watermarking (Images & Video):")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            TextField("Watermark text", text: $watermarkText)
                .textFieldStyle(.roundedBorder)
            
            Picker("Anchor Position", selection: $watermarkAnchor) {
                ForEach(WatermarkAnchor.allCases) { anchor in
                    Text(anchor.rawValue).tag(anchor)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Opacity: \(Int(watermarkOpacity * 100))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Slider(value: $watermarkOpacity, in: 0.1...1.0, step: 0.05)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Font Size: \(Int(watermarkFontSize)) pt")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Slider(value: $watermarkFontSize, in: 12.0...72.0, step: 2.0)
            }
        }
    }
    
    private var removeBgView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("On-device Apple Vision subject segmentation isolates foreground subjects cleanly with alpha transparency.")
                .font(.subheadline)
                .foregroundStyle(TossyColor.textSecondary)

            if let first = sourceURLs.first {
                if let out = outputURL, let srcImg = NSImage(contentsOf: first), let outImg = NSImage(contentsOf: out) {
                    // Live Side-by-Side Comparison Container
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Label("Side-by-Side Comparison", systemImage: "rectangle.split.2x1")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(TossyColor.textPrimary)
                            Spacer()
                            Button {
                                showingComparison = true
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "square.split.2x1")
                                    Text("Open Split Slider")
                                }
                                .font(.system(size: 11, weight: .medium))
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .help("Launch full interactive split slider and artifact inspector")
                        }

                        HStack(spacing: 14) {
                            // Left: Original Image
                            VStack(spacing: 6) {
                                HStack {
                                    Text("Original Photo")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(TossyColor.textSecondary)
                                    Spacer()
                                    let sz = (try? first.resourceValues(forKeys: [.fileSizeKey]).fileSize).flatMap { Int64($0) } ?? 0
                                    Text(ByteSize.displayString(sz))
                                        .font(.caption2.monospaced())
                                        .foregroundStyle(TossyColor.textTertiary)
                                }

                                Image(nsImage: srcImg)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(height: 190)
                                    .frame(maxWidth: .infinity)
                                    .background(TossyColor.surfaceElevated)
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .strokeBorder(TossyColor.borderSubtle, lineWidth: 1)
                                    )
                            }

                            // Right: Isolated Subject with Checkerboard Background
                            VStack(spacing: 6) {
                                HStack {
                                    Text("Isolated Subject (Alpha PNG)")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(TossyColor.textSecondary)
                                    Spacer()
                                    let sz = (try? out.resourceValues(forKeys: [.fileSizeKey]).fileSize).flatMap { Int64($0) } ?? 0
                                    Text(ByteSize.displayString(sz))
                                        .font(.caption2.monospaced())
                                        .foregroundStyle(TossyColor.textTertiary)
                                }

                                ZStack {
                                    CheckerboardPattern()

                                    Image(nsImage: outImg)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                }
                                .frame(height: 190)
                                .frame(maxWidth: .infinity)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .strokeBorder(TossyColor.borderSubtle, lineWidth: 1)
                                )
                            }
                        }
                    }
                    .padding(12)
                    .background(TossyColor.surfaceBase)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(TossyColor.borderSubtle, lineWidth: 1)
                    )
                } else if let srcImg = NSImage(contentsOf: first) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Selected Photo:")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(TossyColor.textSecondary)

                        HStack(spacing: 14) {
                            Image(nsImage: srcImg)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 140, height: 140)
                                .background(TossyColor.surfaceElevated)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .strokeBorder(TossyColor.borderSubtle, lineWidth: 1)
                                )

                            VStack(alignment: .leading, spacing: 6) {
                                Text(first.lastPathComponent)
                                    .font(.system(size: 13, weight: .bold))
                                    .lineLimit(1)

                                Text("Dimensions: \(Int(srcImg.size.width)) × \(Int(srcImg.size.height))")
                                    .font(.caption)
                                    .foregroundStyle(TossyColor.textSecondary)

                                Text("Click 'Isolate Subject & Remove BG' below to run on-device Apple Vision segmentation.")
                                    .font(.caption2)
                                    .foregroundStyle(TossyColor.textTertiary)
                            }
                            Spacer()
                        }
                    }
                    .padding(12)
                    .background(TossyColor.surfaceBase)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(TossyColor.borderSubtle, lineWidth: 1)
                    )
                }
            } else {
                Text("No image selected. Please drop or queue an image to isolate its subject.")
                    .font(.caption)
                    .foregroundStyle(TossyColor.textTertiary)
            }
        }
    }
    
    private func executeAction() {
        guard let first = sourceURLs.first else { return }
        isProcessing = true
        statusMessage = "Processing media..."
        
        let destinationFolder = first.deletingLastPathComponent()
        let baseName = first.deletingPathExtension().lastPathComponent
        let isVideo = ["mov", "mp4", "m4v", "mkv", "webm", "avi"].contains(first.pathExtension.lowercased())
        
        Task {
            do {
                switch selectedTab {
                case .trim:
                    let start = Double(trimStartText) ?? 0.0
                    let end = Double(trimEndText) ?? 10.0
                    let desired = destinationFolder.appendingPathComponent("\(baseName)_trimmed.mp4")
                    let res = try await LosslessVideoTrimmer.shared.trim(sourceURL: first, startTimeSeconds: start, endTimeSeconds: end, destinationURL: desired)
                    await MainActor.run {
                        self.outputURL = res
                        self.statusMessage = "Trimmed successfully."
                        self.isProcessing = false
                    }
                case .extractAudio:
                    let desired = destinationFolder.appendingPathComponent("\(baseName).\(audioFormat.rawValue)")
                    let res = try await AudioExtractorService.shared.extractAudioTrack(videoURL: first, format: audioFormat, destinationURL: desired)
                    await MainActor.run {
                        self.outputURL = res
                        self.statusMessage = "Extracted \(audioFormat.rawValue.uppercased()) audio."
                        self.isProcessing = false
                    }
                case .stripAudio:
                    let desired = destinationFolder.appendingPathComponent("\(baseName)_silent.mp4")
                    let res = try await AudioExtractorService.shared.stripAudio(videoURL: first, destinationURL: desired)
                    await MainActor.run {
                        self.outputURL = res
                        self.statusMessage = "Stripped audio successfully."
                        self.isProcessing = false
                    }
                case .rotateSpeed:
                    let desired = destinationFolder.appendingPathComponent("\(baseName)_transformed.mp4")
                    let res = try await VideoGeometrySpeedService.shared.transformVideo(
                        sourceURL: first,
                        degrees: rotationDegrees,
                        flipHorizontal: flipHorizontal,
                        flipVertical: flipVertical,
                        speedMultiplier: speedMultiplier,
                        destinationURL: desired
                    )
                    await MainActor.run {
                        self.outputURL = res
                        self.statusMessage = "Transformed video successfully."
                        self.isProcessing = false
                    }
                case .watermark:
                    if isVideo {
                        let desired = destinationFolder.appendingPathComponent("\(baseName)_watermarked.mp4")
                        let res = try await WatermarkService.shared.applyTextWatermarkToVideo(
                            videoURL: first,
                            text: watermarkText,
                            anchor: watermarkAnchor,
                            opacity: watermarkOpacity,
                            fontSize: watermarkFontSize,
                            destinationURL: desired
                        )
                        await MainActor.run {
                            self.outputURL = res
                            self.statusMessage = "Applied watermark to video successfully."
                            self.isProcessing = false
                        }
                    } else {
                        let desired = destinationFolder.appendingPathComponent("\(baseName)_watermarked.png")
                        let res = try await WatermarkService.shared.applyTextWatermark(
                            imageURL: first,
                            text: watermarkText,
                            anchor: watermarkAnchor,
                            opacity: watermarkOpacity,
                            fontSize: watermarkFontSize,
                            destinationURL: desired
                        )
                        await MainActor.run {
                            self.outputURL = res
                            self.statusMessage = "Applied watermark to image successfully."
                            self.isProcessing = false
                        }
                    }
                case .removeBg:
                    let desired = destinationFolder.appendingPathComponent("\(baseName)_nobg.png")
                    let res = try await NeuralSubjectSegmentationService.shared.removeBackground(imageURL: first, destinationURL: desired)
                    await MainActor.run {
                        self.outputURL = res
                        self.statusMessage = "Removed background successfully."
                        self.isProcessing = false
                    }
                }
            } catch {
                await MainActor.run {
                    self.statusMessage = error.localizedDescription
                    self.isProcessing = false
                }
            }
        }
    }
}
