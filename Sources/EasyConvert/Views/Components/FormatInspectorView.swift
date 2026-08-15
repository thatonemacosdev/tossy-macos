import SwiftUI

enum FormatInspectorCategory {
    case image(format: ImageFormat)
    case video(format: VideoFormat)
    case audio(format: AudioFormat)
}

struct FormatInspectorView: View {
    let category: FormatInspectorCategory
    @Bindable var settings = AppSettings.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack {
                Label(headerTitle, systemImage: "slider.horizontal.3")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.white)
                
                Spacer()
                
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(.white)
                .foregroundStyle(.black)
                .controlSize(.small)
            }
            
            Divider().overlay(TossyColor.borderSubtle)
            
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 14) {
                    switch category {
                    case .image(let format):
                        imageSettingsContent(for: format)
                    case .video(let format):
                        videoSettingsContent(for: format)
                    case .audio(let format):
                        audioSettingsContent(for: format)
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(maxHeight: 380)
        }
        .padding(16)
        .frame(width: 380)
        .background(TossyColor.pitchBlack)
        .preferredColorScheme(.dark)
    }
    
    private var headerTitle: String {
        switch category {
        case .image(let format): return "\(format.displayName) CLI Knobs"
        case .video(let format): return "\(format.displayName) Encoding Knobs"
        case .audio(let format): return "\(format.displayName) Audio Knobs"
        }
    }
    
    // MARK: - Image Settings Views
    
    @ViewBuilder
    private func imageSettingsContent(for format: ImageFormat) -> some View {
        switch format {
        case .webp:
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Lossless Encoding (-lossless)", isOn: $settings.webpConfig.isLossless)
                    .toggleStyle(.checkbox)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Compression Method / Effort: \(settings.webpConfig.method)")
                            .font(.caption)
                            .foregroundStyle(TossyColor.textSecondary)
                        Spacer()
                        Text(settings.webpConfig.method == 6 ? "Slowest / Best" : (settings.webpConfig.method == 0 ? "Fastest" : "Balanced"))
                            .font(.caption2)
                            .foregroundStyle(TossyColor.textTertiary)
                    }
                    Slider(value: Binding(
                        get: { Double(settings.webpConfig.method) },
                        set: { settings.webpConfig.method = Int($0) }
                    ), in: 0...6, step: 1)
                }
                
                Picker("WebP Preset (-preset)", selection: $settings.webpConfig.preset) {
                    Text("Default").tag("default")
                    Text("Photo (natural photos)").tag("photo")
                    Text("Picture (indoor / portraits)").tag("picture")
                    Text("Drawing (high contrast)").tag("drawing")
                    Text("Icon (small icons)").tag("icon")
                    Text("Text (text-heavy)").tag("text")
                }
                .pickerStyle(.menu)
                
                Toggle("Sharp YUV Color Mapping (-sharp_yuv)", isOn: $settings.webpConfig.sharpYuv)
                    .toggleStyle(.checkbox)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Filter Strength / SNS: \(settings.webpConfig.filterStrength)")
                        .font(.caption)
                        .foregroundStyle(TossyColor.textSecondary)
                    Slider(value: Binding(
                        get: { Double(settings.webpConfig.filterStrength) },
                        set: { settings.webpConfig.filterStrength = Int($0) }
                    ), in: 0...100, step: 5)
                }
            }
            
        case .jxl:
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Lossless Mode (--distance 0)", isOn: $settings.jxlConfig.isLossless)
                    .toggleStyle(.checkbox)
                
                if !settings.jxlConfig.isLossless {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(String(format: "Visual Distance: %.1f", settings.jxlConfig.distance))
                                .font(.caption)
                                .foregroundStyle(TossyColor.textSecondary)
                            Spacer()
                            Text(settings.jxlConfig.distance <= 1.0 ? "High Quality" : "Higher Compression")
                                .font(.caption2)
                                .foregroundStyle(TossyColor.textTertiary)
                        }
                        Slider(value: $settings.jxlConfig.distance, in: 0.1...10.0, step: 0.1)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Encoder Effort: \(settings.jxlConfig.effort)")
                            .font(.caption)
                            .foregroundStyle(TossyColor.textSecondary)
                        Spacer()
                        Text("1 (fast) ... 9 (best)")
                            .font(.caption2)
                            .foregroundStyle(TossyColor.textTertiary)
                    }
                    Slider(value: Binding(
                        get: { Double(settings.jxlConfig.effort) },
                        set: { settings.jxlConfig.effort = Int($0) }
                    ), in: 1...9, step: 1)
                }
                
                Picker("Faster Decoding Mode", selection: $settings.jxlConfig.fasterDecoding) {
                    Text("0 - Default").tag(0)
                    Text("1 - Light acceleration").tag(1)
                    Text("2 - Medium acceleration").tag(2)
                    Text("3 - Max acceleration").tag(3)
                }
                .pickerStyle(.menu)
            }
            
        case .jpeg:
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Progressive Scan Mode", isOn: $settings.jpegConfig.isProgressive)
                    .toggleStyle(.checkbox)
                
                Picker("Chroma Subsampling", selection: $settings.jpegConfig.chromaSubsampling) {
                    Text("4:2:0 (Standard - Best compression)").tag("4:2:0")
                    Text("4:2:2 (High color fidelity)").tag("4:2:2")
                    Text("4:4:4 (Full color resolution / crisp text)").tag("4:4:4")
                }
                .pickerStyle(.menu)
            }
            
        case .png:
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Deflate Compression Level: \(settings.pngConfig.compressionLevel)")
                            .font(.caption)
                            .foregroundStyle(TossyColor.textSecondary)
                        Spacer()
                        Text("0 (none) ... 9 (max)")
                            .font(.caption2)
                            .foregroundStyle(TossyColor.textTertiary)
                    }
                    Slider(value: Binding(
                        get: { Double(settings.pngConfig.compressionLevel) },
                        set: { settings.pngConfig.compressionLevel = Int($0) }
                    ), in: 0...9, step: 1)
                }
                
                Toggle("Adam7 Interlaced (Progressive PNG)", isOn: $settings.pngConfig.isInterlaced)
                    .toggleStyle(.checkbox)
            }
            
        case .tiff:
            VStack(alignment: .leading, spacing: 12) {
                Picker("TIFF Compression Scheme", selection: $settings.tiffConfig.compression) {
                    Text("LZW (Lossless, widely compatible)").tag("LZW")
                    Text("Deflate / ZIP (High lossless compression)").tag("Deflate")
                    Text("PackBits (RLE)").tag("PackBits")
                    Text("None (Uncompressed)").tag("None")
                }
                .pickerStyle(.menu)
            }
            
        case .gif:
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Max Color Palette: \(settings.gifConfig.maxColors) colors")
                        .font(.caption)
                        .foregroundStyle(TossyColor.textSecondary)
                    Slider(value: Binding(
                        get: { Double(settings.gifConfig.maxColors) },
                        set: { settings.gifConfig.maxColors = Int($0) }
                    ), in: 16...256, step: 16)
                }
                
                Toggle("Enable Floyd-Steinberg Dithering", isOn: $settings.gifConfig.dither)
                    .toggleStyle(.checkbox)
            }
            
        default:
            VStack(alignment: .leading, spacing: 8) {
                Text("Standard ImageIO / FFmpeg pipeline settings applied for \(format.displayName).")
                    .font(.caption)
                    .foregroundStyle(TossyColor.textSecondary)
                Text("Quality, target size, and multi-resolution controls are available in the top bar.")
                    .font(.caption2)
                    .foregroundStyle(TossyColor.textTertiary)
            }
        }
    }
    
    // MARK: - Video Settings Views
    
    @ViewBuilder
    private func videoSettingsContent(for format: VideoFormat) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Rate Control Mode", selection: $settings.videoConfig.encodingMode) {
                Text("Constant Rate Factor (CRF)").tag("crf")
                Text("Target Bitrate / Target Size").tag("bitrate")
                if format.exportPreset != nil {
                    Text("Hardware Acceleration (VideoToolbox)").tag("hardware")
                }
            }
            .pickerStyle(.segmented)
            
            if settings.videoConfig.encodingMode == "crf" {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("CRF Quality Level: \(settings.videoConfig.crfValue)")
                            .font(.caption)
                            .foregroundStyle(TossyColor.textSecondary)
                        Spacer()
                        Text(settings.videoConfig.crfValue <= 18 ? "Visually Lossless" : (settings.videoConfig.crfValue <= 23 ? "Default (High Quality)" : "Compact Size"))
                            .font(.caption2)
                            .foregroundStyle(TossyColor.textTertiary)
                    }
                    Slider(value: Binding(
                        get: { Double(settings.videoConfig.crfValue) },
                        set: { settings.videoConfig.crfValue = Int($0) }
                    ), in: 0...51, step: 1)
                }
            }
            
            Picker("Encoder Speed Preset (-preset)", selection: $settings.videoConfig.x264Preset) {
                Text("ultrafast (fastest, lowest compression)").tag("ultrafast")
                Text("superfast").tag("superfast")
                Text("veryfast").tag("veryfast")
                Text("faster").tag("faster")
                Text("fast").tag("fast")
                Text("medium (balanced)").tag("medium")
                Text("slow (high compression)").tag("slow")
                Text("slower").tag("slower")
                Text("veryslow (best compression)").tag("veryslow")
            }
            .pickerStyle(.menu)
            
            Picker("Pixel Format (-pix_fmt)", selection: $settings.videoConfig.pixelFormat) {
                Text("yuv420p (Standard 8-bit, 100% compatible)").tag("yuv420p")
                Text("yuv420p10le (10-bit HDR / banding-free)").tag("yuv420p10le")
                Text("yuv422p (Broadcast 4:2:2)").tag("yuv422p")
                Text("yuv444p (Full 4:4:4 color)").tag("yuv444p")
            }
            .pickerStyle(.menu)
            
            Divider().overlay(TossyColor.borderSubtle)
            
            HStack(spacing: 12) {
                Picker("Framerate", selection: $settings.videoConfig.frameRate) {
                    Text("Keep source").tag("keep")
                    Text("24 fps (Cinema)").tag("24")
                    Text("25 fps (PAL)").tag("25")
                    Text("29.97 fps (NTSC)").tag("29.97")
                    Text("30 fps").tag("30")
                    Text("50 fps").tag("50")
                    Text("60 fps").tag("60")
                }
                .pickerStyle(.menu)
                
                Picker("Scale Algorithm", selection: $settings.videoConfig.scalingAlgorithm) {
                    Text("Lanczos (Sharpest)").tag("lanczos")
                    Text("Bicubic (Standard)").tag("bicubic")
                    Text("Bilinear (Soft)").tag("bilinear")
                }
                .pickerStyle(.menu)
            }
            
            Toggle("Deinterlace Video (Yadif filter)", isOn: $settings.videoConfig.deinterlace)
                .toggleStyle(.checkbox)
            
            Divider().overlay(TossyColor.borderSubtle)
            
            // Audio in video
            HStack(spacing: 12) {
                Picker("Audio Codec", selection: $settings.videoConfig.audioCodec) {
                    Text("Auto (Format default)").tag("auto")
                    Text("AAC (Standard)").tag("aac")
                    Text("MP3").tag("mp3")
                    Text("Opus (High quality)").tag("opus")
                    Text("AC3 (Dolby)").tag("ac3")
                    Text("Copy audio stream").tag("copy")
                    Text("Mute / No audio").tag("none")
                }
                .pickerStyle(.menu)
                
                if settings.videoConfig.audioCodec != "none" && settings.videoConfig.audioCodec != "copy" {
                    Picker("Audio Bitrate", selection: $settings.videoConfig.audioBitrateKbps) {
                        Text("96 kbps").tag(96)
                        Text("128 kbps").tag(128)
                        Text("192 kbps").tag(192)
                        Text("256 kbps").tag(256)
                        Text("320 kbps").tag(320)
                    }
                    .pickerStyle(.menu)
                }
            }
        }
    }
    
    // MARK: - Audio Settings Views
    
    @ViewBuilder
    private func audioSettingsContent(for format: AudioFormat) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Bitrate Mode", selection: $settings.audioConfig.bitrateMode) {
                Text("Constant (CBR)").tag("cbr")
                Text("Variable (VBR)").tag("vbr")
                Text("Average (ABR)").tag("abr")
            }
            .pickerStyle(.segmented)
            
            if settings.audioConfig.bitrateMode == "vbr" {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("VBR Quality Level: V\(settings.audioConfig.vbrQuality)")
                            .font(.caption)
                            .foregroundStyle(TossyColor.textSecondary)
                        Spacer()
                        Text(settings.audioConfig.vbrQuality <= 1 ? "Highest (~240-280k)" : (settings.audioConfig.vbrQuality <= 4 ? "Standard (~160-200k)" : "Smaller File"))
                            .font(.caption2)
                            .foregroundStyle(TossyColor.textTertiary)
                    }
                    Slider(value: Binding(
                        get: { Double(settings.audioConfig.vbrQuality) },
                        set: { settings.audioConfig.vbrQuality = Int($0) }
                    ), in: 0...9, step: 1)
                }
            } else {
                Picker("Target Audio Bitrate", selection: $settings.audioConfig.cbrBitrateKbps) {
                    Text("64 kbps (Speech)").tag(64)
                    Text("96 kbps").tag(96)
                    Text("128 kbps (Standard)").tag(128)
                    Text("160 kbps").tag(160)
                    Text("192 kbps (High quality)").tag(192)
                    Text("256 kbps (Very high quality)").tag(256)
                    Text("320 kbps (Maximum MP3/AAC)").tag(320)
                }
                .pickerStyle(.menu)
            }
            
            Divider().overlay(TossyColor.borderSubtle)
            
            HStack(spacing: 12) {
                Picker("Sample Rate", selection: $settings.audioConfig.sampleRateHz) {
                    Text("Keep source").tag("keep")
                    Text("44.1 kHz (CD Audio)").tag("44100")
                    Text("48.0 kHz (Broadcast / Video)").tag("48000")
                    Text("88.2 kHz").tag("88200")
                    Text("96.0 kHz (Hi-Res)").tag("96000")
                    Text("192.0 kHz (Studio)").tag("192000")
                }
                .pickerStyle(.menu)
                
                Picker("Channels", selection: $settings.audioConfig.channels) {
                    Text("Keep source").tag("keep")
                    Text("Stereo (2.0)").tag("stereo")
                    Text("Mono (1.0)").tag("mono")
                    Text("Downmix 5.1 to Stereo").tag("downmix51")
                }
                .pickerStyle(.menu)
            }
            
            if format == .flac || format == .wav || format == .aiff || format == .alac || format == .caf {
                Picker("Lossless Bit Depth", selection: $settings.audioConfig.losslessBitDepth) {
                    Text("16-bit (CD Standard)").tag("16")
                    Text("24-bit (Hi-Res Studio)").tag("24")
                    Text("32-bit Float (Mastering)").tag("32")
                }
                .pickerStyle(.menu)
            }
            
            if format == .flac {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("FLAC Compression Level: \(settings.audioConfig.flacCompressionLevel)")
                            .font(.caption)
                            .foregroundStyle(TossyColor.textSecondary)
                        Spacer()
                        Text("0 (fast) ... 8 (max)")
                            .font(.caption2)
                            .foregroundStyle(TossyColor.textTertiary)
                    }
                    Slider(value: Binding(
                        get: { Double(settings.audioConfig.flacCompressionLevel) },
                        set: { settings.audioConfig.flacCompressionLevel = Int($0) }
                    ), in: 0...8, step: 1)
                }
            }
            
            if format == .opus {
                Picker("Opus Tuning Mode", selection: $settings.audioConfig.opusApplication) {
                    Text("Audio (Full fidelity music & sound)").tag("audio")
                    Text("VoIP (Optimized for human voice)").tag("voip")
                    Text("Low Delay (Real-time latency)").tag("lowdelay")
                }
                .pickerStyle(.menu)
            }
            
            Divider().overlay(TossyColor.borderSubtle)
            
            Toggle("EBU R128 Volume Normalization (-af loudnorm)", isOn: $settings.audioConfig.normalizeEBUR128)
                .toggleStyle(.checkbox)
                .help("Normalizes integrated loudness to -24 LUFS standard broadcast volume")
        }
    }
}
