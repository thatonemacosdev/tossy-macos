import SwiftUI
import AppKit

enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "General"
    case images = "Images"
    case video = "Video"
    case audio = "Audio"
    case tools = "CLI & Tools"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .images: return "photo"
        case .video: return "video"
        case .audio: return "waveform"
        case .tools: return "terminal"
        }
    }
}

struct SettingsView: View {
    @State private var selectedTab: SettingsTab = .general
    @Bindable var settings = AppSettings.shared
    
    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettingsTab()
                .tabItem { Label(SettingsTab.general.rawValue, systemImage: SettingsTab.general.icon) }
                .tag(SettingsTab.general)
            
            ImagesSettingsTab()
                .tabItem { Label(SettingsTab.images.rawValue, systemImage: SettingsTab.images.icon) }
                .tag(SettingsTab.images)
            
            VideoSettingsTab()
                .tabItem { Label(SettingsTab.video.rawValue, systemImage: SettingsTab.video.icon) }
                .tag(SettingsTab.video)
            
            AudioSettingsTab()
                .tabItem { Label(SettingsTab.audio.rawValue, systemImage: SettingsTab.audio.icon) }
                .tag(SettingsTab.audio)
            
            ToolsSettingsTab()
                .tabItem { Label(SettingsTab.tools.rawValue, systemImage: SettingsTab.tools.icon) }
                .tag(SettingsTab.tools)
        }
        .frame(width: 580, height: 460)
        .padding(20)
        .background(TossyColor.pitchBlack)
        .preferredColorScheme(.dark)
    }
}

// MARK: - General Settings Tab

struct GeneralSettingsTab: View {
    @Bindable var settings = AppSettings.shared
    
    var body: some View {
        Form {
            Section("Output Destination & File Handling") {
                Picker("Default Output Location", selection: $settings.destinationPolicy) {
                    ForEach(DestinationPolicy.allCases) { policy in
                        Text(policy.rawValue).tag(policy)
                    }
                }
                
                if settings.destinationPolicy == .customFolder {
                    HStack {
                        Text(settings.customDestinationPath.isEmpty ? "No folder chosen" : settings.customDestinationPath)
                            .font(.caption)
                            .foregroundStyle(TossyColor.textSecondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        
                        Spacer()
                        
                        Button("Choose Folder…") {
                            chooseFolder()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                
                Picker("When File Exists", selection: $settings.fileConflictAction) {
                    ForEach(FileConflictAction.allCases) { action in
                        Text(action.rawValue).tag(action)
                    }
                }
            }
            
            Section("Performance & Limits") {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Max Concurrent Conversion Tasks: \(settings.maxConcurrentJobs)")
                        Spacer()
                        Text("System cores: \(ProcessInfo.processInfo.activeProcessorCount)")
                            .font(.caption2)
                            .foregroundStyle(TossyColor.textTertiary)
                    }
                    Slider(value: Binding(
                        get: { Double(settings.maxConcurrentJobs) },
                        set: { settings.maxConcurrentJobs = Int($0) }
                    ), in: 1...8, step: 1)
                }
                
                Picker("Safety Size Threshold", selection: Binding(
                    get: { settings.maxFileSizeBytes },
                    set: { settings.maxFileSizeBytes = $0 }
                )) {
                    ForEach(AppSettings.sizePresets, id: \.label) { preset in
                        Text(preset.label).tag(preset.bytes)
                    }
                }
            }
            
            Section("Workflow & Feedback") {
                Toggle("Send macOS Notification when batch finishes", isOn: $settings.notifyOnComplete)
                    .toggleStyle(.checkbox)
                
                Toggle("Play subtle audio chime on completion", isOn: $settings.playCompletionSound)
                    .toggleStyle(.checkbox)
                
                Toggle("Auto-reveal output file in Finder when completed", isOn: $settings.autoRevealInFinder)
                    .toggleStyle(.checkbox)
                
                Toggle("Delete source file after successful conversion (Caution)", isOn: $settings.deleteSourceAfterConversion)
                    .toggleStyle(.checkbox)
                    .foregroundStyle(settings.deleteSourceAfterConversion ? TossyColor.warningAmber : TossyColor.textPrimary)
            }
        }
        .formStyle(.grouped)
    }
    
    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select Output Folder"
        if panel.runModal() == .OK, let url = panel.url {
            settings.customDestinationPath = url.path
        }
    }
}

// MARK: - Images Settings Tab

struct ImagesSettingsTab: View {
    @Bindable var settings = AppSettings.shared
    
    var body: some View {
        Form {
            Section("WebP Defaults (cwebp)") {
                Toggle("Default Lossless", isOn: $settings.webpConfig.isLossless)
                    .toggleStyle(.checkbox)
                
                Picker("Compression Method", selection: $settings.webpConfig.method) {
                    Text("0 - Fastest").tag(0)
                    Text("2 - Fast").tag(2)
                    Text("4 - Default").tag(4)
                    Text("6 - Max Compression").tag(6)
                }
                
                Toggle("Sharp YUV Color Conversion", isOn: $settings.webpConfig.sharpYuv)
                    .toggleStyle(.checkbox)
            }
            
            Section("JPEG XL Defaults (cjxl)") {
                Toggle("Default Lossless", isOn: $settings.jxlConfig.isLossless)
                    .toggleStyle(.checkbox)
                
                Stepper("Effort Level: \(settings.jxlConfig.effort)", value: $settings.jxlConfig.effort, in: 1...9)
            }
            
            Section("JPEG & PNG Defaults") {
                Toggle("JPEG Progressive Mode", isOn: $settings.jpegConfig.isProgressive)
                    .toggleStyle(.checkbox)
                
                Picker("JPEG Chroma Subsampling", selection: $settings.jpegConfig.chromaSubsampling) {
                    Text("4:2:0 (Standard)").tag("4:2:0")
                    Text("4:2:2 (High color)").tag("4:2:2")
                    Text("4:4:4 (Crisp text)").tag("4:4:4")
                }
                
                Stepper("PNG Compression Level: \(settings.pngConfig.compressionLevel)", value: $settings.pngConfig.compressionLevel, in: 0...9)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Video Settings Tab

struct VideoSettingsTab: View {
    @Bindable var settings = AppSettings.shared
    
    var body: some View {
        Form {
            Section("Encoding & Quality") {
                Picker("Default Video Encoding Mode", selection: $settings.videoConfig.encodingMode) {
                    Text("Constant Rate Factor (CRF)").tag("crf")
                    Text("Target Bitrate").tag("bitrate")
                    Text("Hardware Acceleration (VideoToolbox)").tag("hardware")
                }
                
                Stepper("Default CRF Quality: \(settings.videoConfig.crfValue)", value: $settings.videoConfig.crfValue, in: 0...51)
                
                Picker("Default Preset Speed", selection: $settings.videoConfig.x264Preset) {
                    Text("ultrafast").tag("ultrafast")
                    Text("veryfast").tag("veryfast")
                    Text("fast").tag("fast")
                    Text("medium (balanced)").tag("medium")
                    Text("slow (higher quality)").tag("slow")
                    Text("veryslow").tag("veryslow")
                }
                
                Picker("Default Pixel Format", selection: $settings.videoConfig.pixelFormat) {
                    Text("yuv420p (8-bit standard)").tag("yuv420p")
                    Text("yuv420p10le (10-bit color)").tag("yuv420p10le")
                    Text("yuv422p (4:2:2)").tag("yuv422p")
                }
            }
            
            Section("Audio & Filters") {
                Picker("Audio Stream Codec", selection: $settings.videoConfig.audioCodec) {
                    Text("Auto (Format default)").tag("auto")
                    Text("AAC").tag("aac")
                    Text("MP3").tag("mp3")
                    Text("Opus").tag("opus")
                    Text("Copy source audio").tag("copy")
                    Text("Mute / Strip audio").tag("none")
                }
                
                Toggle("Auto-deinterlace video", isOn: $settings.videoConfig.deinterlace)
                    .toggleStyle(.checkbox)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Audio Settings Tab

struct AudioSettingsTab: View {
    @Bindable var settings = AppSettings.shared
    
    var body: some View {
        Form {
            Section("Bitrate & Quality") {
                Picker("Bitrate Mode", selection: $settings.audioConfig.bitrateMode) {
                    Text("Constant (CBR)").tag("cbr")
                    Text("Variable (VBR)").tag("vbr")
                }
                
                Picker("Default CBR Bitrate", selection: $settings.audioConfig.cbrBitrateKbps) {
                    Text("128 kbps").tag(128)
                    Text("160 kbps").tag(160)
                    Text("192 kbps").tag(192)
                    Text("256 kbps").tag(256)
                    Text("320 kbps").tag(320)
                }
                
                Picker("Default Sample Rate", selection: $settings.audioConfig.sampleRateHz) {
                    Text("Keep source").tag("keep")
                    Text("44.1 kHz (CD)").tag("44100")
                    Text("48.0 kHz (Video/Broadcast)").tag("48000")
                    Text("96.0 kHz (Hi-Res)").tag("96000")
                }
            }
            
            Section("Lossless & Processing") {
                Picker("Lossless Bit Depth", selection: $settings.audioConfig.losslessBitDepth) {
                    Text("16-bit").tag("16")
                    Text("24-bit").tag("24")
                    Text("32-bit Float").tag("32")
                }
                
                Stepper("FLAC Compression: \(settings.audioConfig.flacCompressionLevel)", value: $settings.audioConfig.flacCompressionLevel, in: 0...8)
                
                Toggle("EBU R128 Broadcast Normalization (-24 LUFS)", isOn: $settings.audioConfig.normalizeEBUR128)
                    .toggleStyle(.checkbox)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - CLI & Tools Tab

struct ToolsSettingsTab: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                toolCard(
                    title: "FFmpeg & FFprobe",
                    icon: "film.stack",
                    status: FFmpegLocator.isAvailable ? "Active (Bundled)" : "Not found",
                    path: FFmpegLocator.ffmpegPath ?? "Unavailable",
                    details: "Encodes: H.264 (x264), HEVC, AV1 (svtav1), VP9/VP8, ProRes, DNxHD, MP3, AAC, Opus, FLAC, AC3, and 30+ formats."
                )
                
                toolCard(
                    title: "WebP Suite (cwebp, dwebp, img2webp)",
                    icon: "photo.stack",
                    status: WebPLocator.cwebpPath != nil ? "Active (Bundled)" : "Not found",
                    path: WebPLocator.cwebpPath ?? "Unavailable",
                    details: "Encodes: Still WebP (lossy & lossless, Sharp YUV, SNS) and Animated WebP."
                )
                
                toolCard(
                    title: "JPEG XL Suite (cjxl, djxl)",
                    icon: "sparkles.rectangle.stack",
                    status: JXLLocator.cjxlPath != nil ? "Active (Bundled)" : "Not found",
                    path: JXLLocator.cjxlPath ?? "Unavailable",
                    details: "Encodes: JPEG XL (lossless, VarDCT, Butteraugli distance tuning, multi-effort)."
                )
                
                toolCard(
                    title: "Hardware Encoders (VideoToolbox & Metal)",
                    icon: "cpu",
                    status: "Hardware Accelerated",
                    path: "Apple Silicon / GPU Metal Pipeline",
                    details: "Metal-backed Core Image processing, VideoToolbox H.264/HEVC/ProRes hardware pipelines."
                )
            }
            .padding(12)
        }
    }
    
    private func toolCard(title: String, icon: String, status: String, path: String, details: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(title, systemImage: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.white)
                
                Spacer()
                
                TossyPill(text: status, icon: "checkmark.circle.fill", isSelected: status.contains("Active") || status.contains("Hardware"))
            }
            
            Text(path)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(TossyColor.textTertiary)
                .lineLimit(1)
                .truncationMode(.middle)
            
            Text(details)
                .font(.system(size: 11))
                .foregroundStyle(TossyColor.textSecondary)
        }
        .padding(12)
        .tossyCard()
    }
}
