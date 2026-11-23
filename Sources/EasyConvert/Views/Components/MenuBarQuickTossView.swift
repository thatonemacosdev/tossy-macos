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
    
    @Namespace private var categoryNamespace
    
    enum QuickCategory: String, CaseIterable, Identifiable {
        case image = "Image"
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
            // MARK: - Header
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(TossyColor.accentProminentBg)
                    
                    Text("Quick-Toss")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(TossyColor.textPrimary)
                        .fixedSize(horizontal: true, vertical: false)
                    
                    Text("v2.2")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(TossyColor.surfaceElevated)
                        .clipShape(Capsule())
                        .foregroundStyle(TossyColor.textTertiary)
                        .fixedSize(horizontal: true, vertical: false)
                }
                
                Spacer()
                
                Button {
                    MenuBarManager.shared.togglePopover()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(TossyColor.textTertiary)
                }
                .buttonStyle(.plain)
                .help("Close Popover")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(TossyColor.surfaceDeep)
            
            Divider().overlay(TossyColor.borderSubtle)
            
            // MARK: - Dedicated Full-Width Category Selector
            HStack(spacing: 4) {
                ForEach(QuickCategory.allCases) { cat in
                    QuickTossCategoryButton(
                        category: cat,
                        isSelected: selectedCategory == cat,
                        namespace: categoryNamespace,
                        action: {
                            selectCategory(cat)
                        }
                    )
                }
            }
            .padding(4)
            .background(TossyColor.surfaceBase)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(TossyColor.borderSubtle, lineWidth: 1)
            )
            .padding(.horizontal, 14)
            .padding(.top, 10)
            
            // MARK: - Main Drop Area / Active Conversion
            VStack(spacing: 10) {
                if !completedOutputs.isEmpty {
                    // Success View
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 34))
                            .foregroundStyle(TossyColor.successGreen)
                        
                        VStack(spacing: 3) {
                            Text("Converted \(completedOutputs.count) file(s)!")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(TossyColor.textPrimary)
                            Text("Saved to default destination")
                                .font(.system(size: 11))
                                .foregroundStyle(TossyColor.textSecondary)
                        }
                        
                        HStack(spacing: 8) {
                            Button {
                                NSWorkspace.shared.activateFileViewerSelecting(completedOutputs)
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "folder")
                                    Text("Show in Finder")
                                        .fixedSize(horizontal: true, vertical: false)
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(TossyColor.accentProminentBg)
                            .foregroundStyle(TossyColor.accentProminentFg)
                            .controlSize(.small)
                            
                            Button("Convert More") {
                                withAnimation(TossyMotion.springSmooth) {
                                    droppedURLs.removeAll()
                                    completedOutputs.removeAll()
                                }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                    .padding(.vertical, 22)
                } else if isConverting {
                    // Progress View
                    VStack(spacing: 10) {
                        ProgressView(value: conversionProgress, total: 1.0)
                            .progressViewStyle(.linear)
                            .frame(width: 240)
                        
                        Text("Converting… \(Int(conversionProgress * 100))%")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(TossyColor.textSecondary)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .padding(.vertical, 28)
                } else if droppedURLs.isEmpty {
                    // Empty Drop Target
                    VStack(spacing: 8) {
                        Image(systemName: isTargeted ? "arrow.down.circle.fill" : "plus.rectangle.on.rectangle")
                            .font(.system(size: 28))
                            .foregroundStyle(isTargeted ? TossyColor.accentProminentBg : TossyColor.textTertiary)
                            .scaleEffect(isTargeted ? 1.15 : 1.0)
                            .animation(TossyMotion.springBouncy, value: isTargeted)
                        
                        VStack(spacing: 2) {
                            Text(isTargeted ? "Release to convert" : "Drop files here to convert")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(TossyColor.textPrimary)
                                .fixedSize(horizontal: true, vertical: false)
                            
                            Text("Auto-detects format • PDF & Code open Studios")
                                .font(.system(size: 10))
                                .foregroundStyle(TossyColor.textTertiary)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 22)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(isTargeted ? TossyColor.surfaceHighlight : TossyColor.surfaceElevated.opacity(0.4))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(
                                isTargeted ? TossyColor.accentProminentBg : TossyColor.borderSubtle,
                                style: StrokeStyle(lineWidth: 1.5, dash: [5])
                            )
                    )
                    .padding(.horizontal, 14)
                    .padding(.top, 8)
                } else {
                    // Queued Files List
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("\(droppedURLs.count) file\(droppedURLs.count == 1 ? "" : "s") queued")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(TossyColor.textSecondary)
                                .fixedSize(horizontal: true, vertical: false)
                            Spacer()
                            Button("Clear All") {
                                withAnimation(TossyMotion.springSnappy) {
                                    droppedURLs.removeAll()
                                }
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(TossyColor.textTertiary)
                        }
                        
                        ForEach(droppedURLs.prefix(4), id: \.self) { url in
                            HStack(spacing: 6) {
                                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 16, height: 16)
                                
                                Text(url.lastPathComponent)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(TossyColor.textPrimary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                Button {
                                    withAnimation(TossyMotion.springSnappy) {
                                        droppedURLs.removeAll(where: { $0 == url })
                                    }
                                } label: {
                                    Image(systemName: "xmark.circle")
                                        .font(.system(size: 11))
                                        .foregroundStyle(TossyColor.textTertiary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(TossyColor.surfaceElevated)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .strokeBorder(TossyColor.borderSubtle, lineWidth: 0.5)
                            )
                        }
                        
                        if droppedURLs.count > 4 {
                            Text("+\(droppedURLs.count - 4) more files")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(TossyColor.textTertiary)
                                .padding(.horizontal, 4)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 6)
                }
                
                // Format Selector Chips & Actions
                if !isConverting && completedOutputs.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Target Format:")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(TossyColor.textTertiary)
                            .padding(.horizontal, 14)
                        
                        HStack(spacing: 6) {
                            switch selectedCategory {
                            case .image:
                                formatChip("WebP", isSelected: selectedImageFormat == .webp) { selectedImageFormat = .webp }
                                formatChip("PNG", isSelected: selectedImageFormat == .png) { selectedImageFormat = .png }
                                formatChip("JPEG", isSelected: selectedImageFormat == .jpeg) { selectedImageFormat = .jpeg }
                                formatChip("JXL", isSelected: selectedImageFormat == .jxl) { selectedImageFormat = .jxl }
                            case .video:
                                formatChip("MP4", isSelected: selectedVideoFormat == .mp4H264) { selectedVideoFormat = .mp4H264 }
                                formatChip("WebM", isSelected: selectedVideoFormat == .webm) { selectedVideoFormat = .webm }
                                formatChip("GIF", isSelected: selectedVideoFormat == .animatedGif) { selectedVideoFormat = .animatedGif }
                                formatChip("MKV", isSelected: selectedVideoFormat == .mkv) { selectedVideoFormat = .mkv }
                            case .audio:
                                formatChip("MP3", isSelected: selectedAudioFormat == .mp3) { selectedAudioFormat = .mp3 }
                                formatChip("AAC", isSelected: selectedAudioFormat == .aac) { selectedAudioFormat = .aac }
                                formatChip("FLAC", isSelected: selectedAudioFormat == .flac) { selectedAudioFormat = .flac }
                                formatChip("WAV", isSelected: selectedAudioFormat == .wav) { selectedAudioFormat = .wav }
                            }
                        }
                        .padding(.horizontal, 14)
                        
                        if !droppedURLs.isEmpty {
                            HStack(spacing: 8) {
                                // Option to bounce to full Studio if media file dropped
                                if selectedCategory == .video || selectedCategory == .image {
                                    Button {
                                        openInStudio()
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: selectedCategory == .image ? "photo.stack" : "film.stack")
                                            Text("Open Studio")
                                                .fixedSize(horizontal: true, vertical: false)
                                        }
                                        .font(.system(size: 11, weight: .medium))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 6)
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                                
                                Button {
                                    startConversion()
                                } label: {
                                    HStack(spacing: 5) {
                                        Image(systemName: "arrow.triangle.2.circlepath")
                                        Text("Convert Now (\(droppedURLs.count))")
                                            .font(.system(size: 11, weight: .bold))
                                            .fixedSize(horizontal: true, vertical: false)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 6)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(TossyColor.accentProminentBg)
                                .foregroundStyle(TossyColor.accentProminentFg)
                                .controlSize(.small)
                            }
                            .padding(.horizontal, 14)
                            .padding(.top, 4)
                        }
                    }
                }
            }
            .padding(.bottom, 12)
            
            Divider().overlay(TossyColor.borderSubtle)
            
            // MARK: - Footer Actions
            HStack {
                Button {
                    onOpenFullApp()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "macwindow")
                            .font(.system(size: 10))
                        Text("Open Full App")
                            .fixedSize(horizontal: true, vertical: false)
                    }
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
                .fixedSize(horizontal: true, vertical: false)
                
                Spacer()
                
                Button("Quit") {
                    onQuit()
                }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundStyle(TossyColor.textTertiary)
                .fixedSize(horizontal: true, vertical: false)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(TossyColor.surfaceDeep)
        }
        .frame(width: 340)
        .background(TossyColor.pitchBlack)
        .preferredColorScheme(AppSettings.shared.appTheme.isDark ? .dark : .light)
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            handleDrop(providers)
            return true
        }
        .onHover { isHovering in
            if isHovering {
                MenuBarManager.shared.cancelCloseTimer()
            } else {
                MenuBarManager.shared.scheduleClose(delay: 0.35)
            }
        }
        .onChange(of: isTargeted) { _, targeted in
            if targeted {
                MenuBarManager.shared.cancelCloseTimer()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TossyMenuBarAddFiles"))) { notif in
            if let urls = notif.userInfo?["urls"] as? [URL], !urls.isEmpty {
                routeIncomingURLs(urls)
            }
        }
    }
    
    private func selectCategory(_ cat: QuickCategory) {
        TossyHaptic.performFeedback(.generic)
        withAnimation(TossyMotion.springSmooth) {
            selectedCategory = cat
        }
    }
    
    private func formatChip(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            TossyHaptic.performFeedback(.generic)
            action()
        } label: {
            Text(title)
                .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .foregroundStyle(isSelected ? TossyColor.accentProminentFg : TossyColor.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
                .background(isSelected ? TossyColor.accentProminentBg : TossyColor.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(isSelected ? TossyColor.accentProminentBg : TossyColor.borderSubtle, lineWidth: 1)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    private func handleDrop(_ providers: [NSItemProvider]) {
        Task { @MainActor in
            let urls = await FileDropResolver.resolveURLs(from: providers)
            routeIncomingURLs(urls)
        }
    }
    
    private func routeIncomingURLs(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        if !completedOutputs.isEmpty {
            completedOutputs.removeAll()
        }
        
        // If code file dropped: auto-open Code Studio in app
        let codeFiles = urls.filter { CodeLanguageDetector.codeExtensions.contains($0.pathExtension.lowercased()) }
        if !codeFiles.isEmpty, let firstCode = codeFiles.first {
            TossyHaptic.performFeedback(.alignment)
            TossySound.playStudioOpen()
            onOpenFullApp()
            NotificationCenter.default.post(
                name: NSNotification.Name("TossyOpenCodeCard"),
                object: nil,
                userInfo: ["url": firstCode]
            )
            return
        }
        
        // If PDF dropped: auto-open PDF Studio in app
        let pdfFiles = urls.filter { $0.pathExtension.lowercased() == "pdf" }
        if !pdfFiles.isEmpty {
            TossyHaptic.performFeedback(.alignment)
            TossySound.playStudioOpen()
            onOpenFullApp()
            NotificationCenter.default.post(
                name: NSNotification.Name("TossyDropFiles"),
                object: nil,
                userInfo: ["urls": pdfFiles]
            )
            return
        }
        
        // Image & Video: queue and play sound/haptic
        for url in urls where !self.droppedURLs.contains(url) {
            self.droppedURLs.append(url)
        }
        TossyHaptic.performFeedback(.generic)
        TossySound.playToss()
        
        if let first = urls.first {
            let ext = first.pathExtension.lowercased()
            withAnimation(TossyMotion.springSmooth) {
                if ["mov", "mp4", "m4v", "mkv", "webm", "avi", "flv", "wmv", "ts", "mts", "m2ts", "ogv", "3gp", "asf", "vob", "dv"].contains(ext) {
                    self.selectedCategory = .video
                } else if ["mp3", "m4a", "wav", "flac", "aac", "ogg", "aiff", "wma", "opus", "alac", "weba", "caf", "m4r", "amr"].contains(ext) {
                    self.selectedCategory = .audio
                } else if ["png", "jpg", "jpeg", "heic", "webp", "gif", "svg", "jxl", "avif", "tiff", "bmp", "ico", "raw", "cr2", "nef", "arw", "dng"].contains(ext) {
                    self.selectedCategory = .image
                } else if VideoFormat.readableExtensions.contains(ext) {
                    self.selectedCategory = .video
                } else if AudioFormat.readableExtensions.contains(ext) {
                    self.selectedCategory = .audio
                } else {
                    self.selectedCategory = .image
                }
            }
        }
    }
    
    private func openInStudio() {
        guard !droppedURLs.isEmpty else { return }
        TossyHaptic.performFeedback(.alignment)
        TossySound.playStudioOpen()
        let urls = droppedURLs
        onOpenFullApp()
        NotificationCenter.default.post(
            name: NSNotification.Name("TossyDropFiles"),
            object: nil,
            userInfo: ["urls": urls]
        )
    }
    
    private func startConversion() {
        guard !droppedURLs.isEmpty else { return }
        isConverting = true
        conversionProgress = 0.1
        TossyHaptic.performFeedback(.generic)
        
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
                TossyHaptic.performFeedback(.alignment)
                TossySound.playCompletion()
            }
        }
    }
}

struct QuickTossCategoryButton: View {
    let category: MenuBarQuickTossView.QuickCategory
    let isSelected: Bool
    var namespace: Namespace.ID
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: category.icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(category.rawValue)
                    .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                    .fixedSize(horizontal: true, vertical: false)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .foregroundStyle(
                isSelected ? TossyColor.accentProminentFg :
                (isHovered ? TossyColor.textPrimary : TossyColor.textSecondary)
            )
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(TossyColor.accentProminentBg)
                        .matchedGeometryEffect(id: "activeCategoryCapsule", in: namespace)
                        .shadow(color: Color.black.opacity(0.18), radius: 3, y: 1)
                } else if isHovered {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(TossyColor.surfaceHighlight)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
