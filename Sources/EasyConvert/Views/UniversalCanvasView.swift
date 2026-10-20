import SwiftUI
import AppKit
import UniformTypeIdentifiers

enum UniversalFormatTarget: Hashable, Identifiable {
    case image(ImageFormat)
    case video(VideoFormat)
    case audio(AudioFormat)
    case pdfAction(String)
    
    var id: String {
        switch self {
        case .image(let f): return "img_\(f.rawValue)"
        case .video(let f): return "vid_\(f.rawValue)"
        case .audio(let f): return "aud_\(f.rawValue)"
        case .pdfAction(let a): return "pdf_\(a)"
        }
    }
    
    var displayName: String {
        switch self {
        case .image(let f): return f.displayName
        case .video(let f): return f.displayName
        case .audio(let f): return f.displayName
        case .pdfAction(let a): return "PDF → \(a)"
        }
    }
    
    var supportsQuality: Bool {
        switch self {
        case .image(let f): return f.supportsQuality
        case .video: return false
        case .audio: return false
        case .pdfAction(let a): return a == "JPEG" || a == "WebP"
        }
    }
    
    var inspectorCategory: FormatInspectorCategory? {
        switch self {
        case .image(let f): return .image(format: f)
        case .video(let f): return .video(format: f)
        case .audio(let f): return .audio(format: f)
        case .pdfAction: return nil
        }
    }
}

struct UniversalCanvasView: View {
    @State private var jobs: [ConversionJob] = []
    @State private var selectedTarget: UniversalFormatTarget = .image(.webp)
    @State private var quality: Double = 0.85
    @State private var destinationFolder: URL?
    @State private var isTargeted = false
    @State private var isConverting = false
    @State private var isShowingImporter = false
    @State private var isShowingInspector = false
    @State private var showAdvanced = false
    @State private var targetSizeText = ""
    @State private var selectedResolutionPreset = "Original"
    @State private var preserveMetadata = true
    @State private var ebuR128Normalize = false
    @State private var batchSummaryText: String?
    
    // Modal Tool States
    @State private var showPDFStudio = false
    @State private var showMediaStudio = false
    @State private var showArchiveModal = false
    @State private var showCodeCards = false
    @State private var showMetadataSanitizer = false
    @State private var showRenamer = false
    @State private var showQualityInspector = false
    @State private var comparisonSource: URL? = nil
    @State private var comparisonOutput: URL? = nil
    @State private var renamePattern = "{name}_v2"
    @State private var selectedCaseTransform: CaseTransform = .original
    
    // Code Card State
    @State private var codeCardInitialCode: String = ""
    @State private var codeCardInitialFileName: String = "snippet.swift"
    
    // Studio Initial Tab States
    @State private var pdfStudioInitialTab: PDFStudioModalView.PDFStudioTab = .merge
    @State private var mediaStudioInitialTab: MediaStudioModalView.MediaStudioTab = .trim
    
    private var effectiveDestinationFolder: URL? {
        let settings = AppSettings.shared
        switch settings.destinationPolicy {
        case .sameAsSource:
            return destinationFolder
        case .customFolder:
            return destinationFolder ?? (settings.customDestinationPath.isEmpty ? nil : URL(fileURLWithPath: settings.customDestinationPath))
        case .askEachTime:
            return destinationFolder
        }
    }
    
    private var totalBytesFormatted: String {
        let total = jobs.reduce(Int64(0)) { sum, job in
            let s = (try? FileManager.default.attributesOfItem(atPath: job.sourceURL.path)[.size] as? Int64) ?? 0
            return sum + s
        }
        return ByteSize.displayString(total)
    }
    
    private let imageExtensions: Set<String> = [
        "png", "jpg", "jpeg", "heic", "webp", "gif", "svg", "jxl", "avif", "tiff", "bmp", "ico", "raw", "dng", "cr2", "nef", "arw"
    ]
    private let videoExtensions: Set<String> = [
        "mov", "mp4", "m4v", "mkv", "webm", "avi", "flv", "wmv", "ts", "mts", "m2ts"
    ]
    private let audioExtensions: Set<String> = [
        "mp3", "m4a", "wav", "flac", "aac", "ogg", "aiff", "wma", "opus", "alac", "caf", "weba"
    ]
    
    private var sourceURLs: [URL] {
        jobs.map(\.sourceURL)
    }

    private var selectedAudioTarget: AudioFormat? {
        if case .audio(let f) = selectedTarget { return f }
        return nil
    }

    private var selectedVideoTarget: VideoFormat? {
        if case .video(let f) = selectedTarget { return f }
        return nil
    }

    private var selectedImageTarget: ImageFormat? {
        if case .image(let f) = selectedTarget { return f }
        return nil
    }
    
    var body: some View {
        GeometryReader { geo in
            let sidebarWidth = max(255, min(330, geo.size.width * 0.28))
            HStack(spacing: 0) {
                // Main Conversion Workspace
                VStack(spacing: 0) {
                    if !jobs.isEmpty {
                        // Control Bar only appears AFTER files are dropped
                        controlBar
                            .transition(.move(edge: .top).combined(with: .opacity))
                        
                        Divider().overlay(TossyColor.borderSubtle)
                        
                        ScrollView {
                            LazyVStack(spacing: 6) {
                                ForEach(jobs) { job in
                                    JobRowView(
                                        job: job,
                                        categoryType: categoryTypeFor(job.sourceURL),
                                        onRetry: {
                                            Task { await convertSingleJob(job) }
                                        },
                                        onRemove: {
                                            withAnimation(TossyMotion.springSmooth) {
                                                jobs.removeAll(where: { $0.id == job.id })
                                            }
                                        }
                                    )
                                }
                            }
                            .padding(12)
                        }
                        
                        Divider().overlay(TossyColor.borderSubtle)
                        
                        bottomBar
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    } else {
                        // Clean, distraction-free Dropzone (Zero format controls shown until dropped)
                        DropZoneView(
                            isTargeted: isTargeted,
                            icon: "arrow.triangle.2.circlepath.circle",
                            title: "Toss any files here to convert",
                            subtitle: "Drop files to automatically detect formats, or choose a tool from the sidebar",
                            formatTags: ["Images", "Video", "Audio", "PDF", "Vision AI", "CLI Knobs"]
                        ) {
                            isShowingImporter = true
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Vertical Three Studios Sidebar
                Divider().overlay(TossyColor.borderSubtle)
                
                threeStudiosSidebar
                    .frame(width: sidebarWidth)
                    .background(
                        AppSettings.shared.appTheme == .titanium ?
                        Color(red: 0.12, green: 0.125, blue: 0.14).opacity(0.68) :
                        (AppSettings.shared.appTheme == .liquidGlass ? Color.white.opacity(0.04) : TossyColor.surfaceDeep)
                    )
            }
        }
        .frame(minWidth: 640, minHeight: 460)
        .background(
            AppSettings.shared.appTheme == .titanium || AppSettings.shared.appTheme == .liquidGlass ?
            Color.clear : TossyColor.pitchBlack
        )
        .contentShape(Rectangle())
        .onDrop(of: [.fileURL, .image, .png, .jpeg, .tiff, .movie, .video, .audio, .pdf, .data, .item], isTargeted: $isTargeted) { providers in
            handleDrop(providers)
        }
        .fileImporter(
            isPresented: $isShowingImporter,
            allowedContentTypes: [.item, .content, .data],
            allowsMultipleSelection: true
        ) { result in
            if case .success(let urls) = result {
                addJobs(for: urls)
            }
        }
        .sheet(isPresented: $showPDFStudio) {
            PDFStudioModalView(sourceURLs: sourceURLs, initialTab: pdfStudioInitialTab)
        }
        .sheet(isPresented: $showMediaStudio) {
            MediaStudioModalView(sourceURLs: sourceURLs, initialTab: mediaStudioInitialTab)
        }
        .sheet(isPresented: $showArchiveModal) {
            ArchiveOptionsModalView(sourceURLs: sourceURLs) { output in
                batchSummaryText = "Created archive: \(output.lastPathComponent)"
            }
        }
        .sheet(isPresented: $showCodeCards) {
            CodeCardModalView(initialCode: codeCardInitialCode, initialFileName: codeCardInitialFileName)
        }
        .sheet(isPresented: $showMetadataSanitizer) {
            EXIFSanitizerModalView(sourceURLs: sourceURLs)
        }
        .sheet(isPresented: $showRenamer) {
            renamerModalSheet
        }
        .sheet(isPresented: $showQualityInspector) {
            if let src = comparisonSource, let out = comparisonOutput {
                BeforeAfterComparisonView(sourceURL: src, outputURL: out)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TossyOpenCodeCard"))) { notif in
            if let url = notif.userInfo?["url"] as? URL,
               let content = try? String(contentsOf: url, encoding: .utf8) {
                self.codeCardInitialCode = content
                self.codeCardInitialFileName = url.lastPathComponent
                self.showCodeCards = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TossyMenuBarAddFiles"))) { notif in
            if let urls = notif.userInfo?["urls"] as? [URL] {
                self.addJobs(for: urls)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TossyDropFiles"))) { notif in
            if let urls = notif.userInfo?["urls"] as? [URL] {
                self.addJobs(for: urls)
            }
        }
    }
    
    // MARK: - Vertical Three Studios Sidebar
    
    private var threeStudiosSidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                // Sidebar Header
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Studios")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(TossyColor.textPrimary)
                        Text("Pro Production Suites")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(TossyColor.textTertiary)
                    }
                    
                    Spacer()
                    
                    if !jobs.isEmpty {
                        Text("\(jobs.count) queued")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(TossyColor.surfaceElevated)
                            .clipShape(Capsule())
                            .foregroundStyle(TossyColor.textSecondary)
                    }
                }
                .padding(.horizontal, 4)
                .padding(.top, 2)
                
                // Studio 1: Media Studio
                studioCard(
                    title: "Media Studio",
                    subtitle: "Video, Audio & AI Vision",
                    icon: "film.stack.fill",
                    gradient: [Color.cyan, Color.blue],
                    onOpen: {
                        mediaStudioInitialTab = .trim
                        showMediaStudio = true
                    },
                    chips: [
                        ("Trim & Cut", "scissors", {
                            mediaStudioInitialTab = .trim
                            showMediaStudio = true
                        }),
                        ("Strip Audio", "waveform", {
                            mediaStudioInitialTab = .extractAudio
                            showMediaStudio = true
                        }),
                        ("AI Remove BG", "person.crop.circle.badge.checkmark", {
                            triggerAIRemoveBG()
                        }),
                        ("Rotate & Speed", "rotate.right", {
                            mediaStudioInitialTab = .rotateSpeed
                            showMediaStudio = true
                        })
                    ]
                )
                
                // Studio 2: PDF Studio
                studioCard(
                    title: "PDF Studio",
                    subtitle: "Burst, Vision OCR & Compress",
                    icon: "doc.richtext.fill",
                    gradient: [Color.orange, Color.red],
                    onOpen: {
                        pdfStudioInitialTab = .merge
                        showPDFStudio = true
                    },
                    chips: [
                        ("Burst to Images", "doc.on.doc.fill", {
                            triggerBurstPDF()
                        }),
                        ("Vision OCR", "text.viewfinder", {
                            pdfStudioInitialTab = .ocr
                            showPDFStudio = true
                        }),
                        ("Compress PDF", "arrow.down.right.and.arrow.up.left", {
                            pdfStudioInitialTab = .compress
                            showPDFStudio = true
                        }),
                        ("Merge & Split", "scissors", {
                            pdfStudioInitialTab = .merge
                            showPDFStudio = true
                        })
                    ]
                )
                
                // Studio 3: Code Card Studio
                studioCard(
                    title: "Code Card Studio",
                    subtitle: "VS Code Syntax to Retina PNG",
                    icon: "curlybraces.square.fill",
                    gradient: [Color.green, Color.teal],
                    onOpen: {
                        showCodeCards = true
                    },
                    chips: [
                        ("New Card", "plus.square.fill", {
                            codeCardInitialCode = "// Paste or write code here\n"
                            codeCardInitialFileName = "snippet.swift"
                            showCodeCards = true
                        }),
                        ("From Clipboard", "doc.on.clipboard.fill", {
                            openCodeCardFromClipboard()
                        }),
                        ("18+ Languages", "text.alignleft", {
                            showCodeCards = true
                        })
                    ]
                )
                
                // Auxiliary Utilities Section
                VStack(alignment: .leading, spacing: 6) {
                    Text("Utilities")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(TossyColor.textTertiary)
                        .padding(.horizontal, 4)
                        .padding(.top, 4)
                    
                    utilityRowButton(title: "Strip EXIF Metadata", icon: "eye.slash.fill") {
                        showMetadataSanitizer = true
                    }
                    utilityRowButton(title: "Encrypted Archive", icon: "lock.shield.fill") {
                        showArchiveModal = true
                    }
                    utilityRowButton(title: "Batch Token Rename", icon: "pencil.line") {
                        showRenamer = true
                    }
                    utilityRowButton(title: "Quality Inspector", icon: "arrow.left.and.right.square.fill") {
                        openQualityInspector()
                    }
                }
            }
            .padding(10)
        }
    }
    
    @ViewBuilder
    private func studioCard(
        title: String,
        subtitle: String,
        icon: String,
        gradient: [Color],
        onOpen: @escaping () -> Void,
        chips: [(String, String, () -> Void)]
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Card Header
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(
                            LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .frame(width: 26, height: 26)
                        .shadow(color: gradient[0].opacity(0.35), radius: 3, y: 1)
                    
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                }
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(TossyColor.textPrimary)
                    
                    Text(subtitle)
                        .font(.system(size: 9))
                        .foregroundStyle(TossyColor.textSecondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Button(action: onOpen) {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(TossyColor.textSecondary)
                        .padding(5)
                        .background(TossyColor.surfaceHighlight.opacity(0.6))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Open \(title)")
            }
            
            // Feature action chips
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 5) {
                ForEach(0..<chips.count, id: \.self) { idx in
                    let chip = chips[idx]
                    Button(action: chip.2) {
                        HStack(spacing: 4) {
                            Image(systemName: chip.1)
                                .font(.system(size: 8, weight: .medium))
                                .foregroundStyle(TossyColor.textSecondary)
                            
                            Text(chip.0)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(TossyColor.textPrimary)
                                .lineLimit(1)
                            
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(TossyColor.surfaceElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .strokeBorder(TossyColor.borderSubtle.opacity(0.6), lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // Primary Open Studio Button
            Button(action: onOpen) {
                HStack {
                    Text("Open Studio")
                        .font(.system(size: 10, weight: .semibold))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(TossyColor.surfaceHighlight.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .foregroundStyle(TossyColor.textPrimary)
            }
            .buttonStyle(.plain)
        }
        .padding(9)
        .background(TossyColor.surfaceBase)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(TossyColor.borderSubtle, lineWidth: 1)
        )
        .brushedTitaniumCard(cornerRadius: 10, isElevated: true)
    }
    
    private func utilityRowButton(
        title: String,
        icon: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundStyle(TossyColor.textSecondary)
                    .frame(width: 14)
                
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(TossyColor.textPrimary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(TossyColor.textTertiary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(TossyColor.surfaceElevated.opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(TossyColor.borderSubtle.opacity(0.5), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
    
    private func triggerAIRemoveBG() {
        let imageJobs = jobs.filter { imageExtensions.contains($0.sourceURL.pathExtension.lowercased()) }
        if !imageJobs.isEmpty {
            executeAIRemoveBG()
        } else {
            mediaStudioInitialTab = .removeBg
            showMediaStudio = true
        }
    }
    
    private func triggerBurstPDF() {
        let pdfJobs = jobs.filter { $0.sourceURL.pathExtension.lowercased() == "pdf" }
        if !pdfJobs.isEmpty {
            executeBurstPDF()
        } else {
            pdfStudioInitialTab = .split
            showPDFStudio = true
        }
    }
    
    private func openCodeCardFromClipboard() {
        if let str = NSPasteboard.general.string(forType: .string), !str.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            self.codeCardInitialCode = str
            self.codeCardInitialFileName = "snippet.txt"
        } else {
            self.codeCardInitialCode = "// Paste or write code here\n"
            self.codeCardInitialFileName = "snippet.swift"
        }
        self.showCodeCards = true
    }
    
    private func openQualityInspector() {
        if jobs.count >= 2 {
            comparisonSource = jobs[0].sourceURL
            comparisonOutput = jobs[1].sourceURL
            showQualityInspector = true
        } else if let first = jobs.first, case .done(let out, _) = first.status {
            comparisonSource = first.sourceURL
            comparisonOutput = out
            showQualityInspector = true
        } else if let first = jobs.first {
            comparisonSource = first.sourceURL
            comparisonOutput = first.sourceURL
            showQualityInspector = true
        }
    }
    
    // MARK: - Control Bar (Appears only after files are dropped)
    
    private var controlBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                // Universal Target Format Picker
                Picker("Convert to", selection: $selectedTarget) {
                    Section("Image Formats") {
                        ForEach(ImageFormat.allCases) { fmt in
                            Text(fmt.displayName).tag(UniversalFormatTarget.image(fmt))
                        }
                    }
                    
                    Section("Video Formats") {
                        ForEach(VideoFormat.allCases) { fmt in
                            Text(fmt.displayName).tag(UniversalFormatTarget.video(fmt))
                        }
                    }
                    
                    Section("Audio Formats") {
                        ForEach(AudioFormat.allCases) { fmt in
                            Text(fmt.displayName).tag(UniversalFormatTarget.audio(fmt))
                        }
                    }
                    
                    Section("PDF & Document Tools") {
                        Text("PDF → PNG Images").tag(UniversalFormatTarget.pdfAction("PNG"))
                        Text("PDF → JPEG Images").tag(UniversalFormatTarget.pdfAction("JPEG"))
                        Text("PDF → WebP Images").tag(UniversalFormatTarget.pdfAction("WebP"))
                        Text("PDF → Compress Document").tag(UniversalFormatTarget.pdfAction("Compress"))
                        Text("PDF → Vision OCR (TXT)").tag(UniversalFormatTarget.pdfAction("OCR"))
                    }
                }
                .frame(width: 230)
                
                // CLI Knobs Popover Button
                if let cat = selectedTarget.inspectorCategory {
                    Button {
                        isShowingInspector = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "slider.horizontal.3")
                            Text("CLI Knobs")
                        }
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(TossyColor.surfaceElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(TossyColor.borderSubtle, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .help("Configure deep CLI encoding parameters for \(selectedTarget.displayName)")
                    .popover(isPresented: $isShowingInspector) {
                        FormatInspectorView(category: cat)
                    }
                }
                
                // Quality Slider
                if selectedTarget.supportsQuality {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Quality \(Int(quality * 100))%")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(TossyColor.textSecondary)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                        Slider(value: $quality, in: 0.1...1.0)
                            .frame(width: 110)
                    }
                    .fixedSize(horizontal: true, vertical: false)
                }
                
                Spacer()
                
                // Destination Button
                DestinationButton(destinationFolder: effectiveDestinationFolder, action: chooseDestinationFolder)
            }
            
            // Advanced Options Disclosure
            DisclosureGroup("Advanced Options & Parameters", isExpanded: $showAdvanced) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 16) {
                        Toggle("Preserve EXIF/GPS/TIFF metadata", isOn: $preserveMetadata)
                            .toggleStyle(.checkbox)
                        
                        Toggle("EBU R128 Loudness DSP", isOn: $ebuR128Normalize)
                            .toggleStyle(.checkbox)
                        
                        TargetSizeField(text: $targetSizeText)
                        
                        Picker("Resolution:", selection: $selectedResolutionPreset) {
                            Text("Original").tag("Original")
                            Text("4K UHD").tag("4K")
                            Text("1080p FHD").tag("1080p")
                            Text("720p HD").tag("720p")
                            Text("50% Half").tag("50%")
                        }
                        .frame(width: 140)
                    }
                }
                .padding(.top, 4)
            }
            .font(.caption)
            .foregroundStyle(TossyColor.textSecondary)
        }
        .padding(14)
        .background(TossyColor.surfaceDeep)
    }
    
    // MARK: - Bottom Bar (Appears when files are queued)
    
    private var bottomBar: some View {
        HStack(spacing: 12) {
            Button("Clear List") {
                withAnimation(TossyMotion.springSmooth) {
                    jobs.removeAll()
                    batchSummaryText = nil
                }
            }
            .buttonStyle(.plain)
            .font(.caption)
            .foregroundStyle(TossyColor.textTertiary)
            .disabled(jobs.isEmpty || isConverting)
            
            if !jobs.isEmpty {
                Text("\(jobs.count) item(s) • \(totalBytesFormatted)")
                    .font(.caption)
                    .foregroundStyle(TossyColor.textSecondary)
            }
            
            if let batchSummaryText {
                Text(batchSummaryText)
                    .font(.caption)
                    .foregroundStyle(TossyColor.textSecondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            let doneJobs = jobs.compactMap { job -> URL? in
                if case .done(let url, _) = job.status { return url }
                return nil
            }
            
            if !doneJobs.isEmpty {
                if comparisonSource != nil && comparisonOutput != nil {
                    Button {
                        showQualityInspector = true
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "rectangle.split.2x1")
                            Text("Compare Side-by-Side")
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    .help("Compare original and converted/cutout side-by-side with transparency checkerboard")
                }
                
                Button("Show in Finder (\(doneJobs.count))") {
                    NSWorkspace.shared.activateFileViewerSelecting(doneJobs)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
            }
            
            Button {
                Task { await convertAll() }
            } label: {
                HStack(spacing: 6) {
                    if isConverting {
                        ProgressView().controlSize(.small)
                        Text("Converting…")
                    } else {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text("Convert All (\(jobs.count))")
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(TossyColor.accentProminentBg)
            .foregroundStyle(TossyColor.accentProminentFg)
            .controlSize(.regular)
            .disabled(jobs.isEmpty || isConverting)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(TossyColor.surfaceDeep)
    }
    
    // MARK: - Helper Methods
    
    private func categoryTypeFor(_ url: URL) -> JobCategoryType {
        let ext = url.pathExtension.lowercased()
        if ext == "webm" || ext == "mkv" || ext == "mp4" || ext == "m4a" || ext == "mov" {
            if let probe = MediaProbe.probe(url: url) {
                if !probe.hasVideo && probe.hasAudio {
                    return .audio
                }
            }
        }
        if videoExtensions.contains(ext) { return .video }
        if audioExtensions.contains(ext) { return .audio }
        return .image
    }
    
    private func chooseDestinationFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select Destination"
        if panel.runModal() == .OK {
            destinationFolder = panel.url
        }
    }
    
    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        Task { @MainActor in
            let urls = await FileDropResolver.resolveURLs(from: providers)
            withAnimation(TossyMotion.springSmooth) {
                self.addJobs(for: urls)
            }
        }
        return true
    }
    
    private func addJobs(for urls: [URL]) {
        var addedAny = false
        for url in urls {
            if !jobs.contains(where: { $0.sourceURL == url }) {
                jobs.append(ConversionJob(sourceURL: url))
                addedAny = true
            }
        }
        
        if addedAny, let first = urls.first {
            // Auto-detect predominant format target based on dropped files
            let ext = first.pathExtension.lowercased()
            if ext == "pdf" {
                selectedTarget = .pdfAction("PNG")
            } else if videoExtensions.contains(ext) {
                if let probe = MediaProbe.probe(url: first), !probe.hasVideo && probe.hasAudio {
                    selectedTarget = .audio(.mp3)
                } else {
                    selectedTarget = .video(.mp4H264)
                }
            } else if audioExtensions.contains(ext) {
                selectedTarget = .audio(.mp3)
            } else if imageExtensions.contains(ext) {
                selectedTarget = .image(.webp)
            }
        }
    }
    
    // MARK: - Conversion Execution Engines
    
    private func convertAll() async {
        isConverting = true
        batchSummaryText = "Converting \(jobs.count) items..."
        
        let imgConverter = ImageConverter()
        let vidConverter = VideoConverter()
        let audConverter = AudioConverter()
        
        let targetBytes = ByteSize.parse(targetSizeText)
        let targetWidth: Int?
        switch selectedResolutionPreset {
        case "4K": targetWidth = 3840
        case "1080p": targetWidth = 1920
        case "720p": targetWidth = 1280
        default: targetWidth = nil
        }
        
        for job in jobs {
            await convertJob(job, img: imgConverter, vid: vidConverter, aud: audConverter, targetBytes: targetBytes, targetWidth: targetWidth)
        }
        
        isConverting = false
        batchSummaryText = "Conversion complete."
        if let firstDone = jobs.first(where: {
            if case .done = $0.status { return true }
            return false
        }), case .done(let out, _) = firstDone.status {
            self.comparisonSource = firstDone.sourceURL
            self.comparisonOutput = out
        }
    }
    
    private func convertSingleJob(_ job: ConversionJob) async {
        let imgConverter = ImageConverter()
        let vidConverter = VideoConverter()
        let audConverter = AudioConverter()
        let targetBytes = ByteSize.parse(targetSizeText)
        let targetWidth: Int? = (selectedResolutionPreset == "4K" ? 3840 : (selectedResolutionPreset == "1080p" ? 1920 : nil))
        await convertJob(job, img: imgConverter, vid: vidConverter, aud: audConverter, targetBytes: targetBytes, targetWidth: targetWidth)
    }
    
    private func convertJob(
        _ job: ConversionJob,
        img: ImageConverter,
        vid: VideoConverter,
        aud: AudioConverter,
        targetBytes: Int64?,
        targetWidth: Int?
    ) async {
        let url = job.sourceURL
        let ext = url.pathExtension.lowercased()
        let dest = effectiveDestinationFolder
        
        job.status = .converting(progress: 0.1, etaText: nil)
        
        do {
            if ext == "pdf" {
                switch selectedTarget {
                case .pdfAction("Compress"):
                    let safeDest = OutputNaming.uniqueOutputURL(for: url, fileExtension: "pdf", destinationFolder: dest)
                    let comp = try await PDFCompressService.shared.compress(source: url, preset: .medium, targetSizeBytes: targetBytes, destination: safeDest)
                    job.status = .done(outputURL: comp.outputURL)
                case .pdfAction("OCR"):
                    let ocr = try await VisionOCRService.shared.extractText(from: url)
                    let outTxt = OutputNaming.uniqueOutputURL(for: url, fileExtension: "txt", destinationFolder: dest)
                    try ocr.combinedText.write(to: outTxt, atomically: true, encoding: .utf8)
                    job.status = .done(outputURL: outTxt)
                default:
                    let fmt: ImageFormat
                    if case .pdfAction(let a) = selectedTarget, a == "JPEG" { fmt = .jpeg }
                    else if case .pdfAction(let a) = selectedTarget, a == "WebP" { fmt = .webp }
                    else { fmt = .png }
                    let folder = dest ?? url.deletingLastPathComponent()
                    let bridge = try await DocImageBridgeService.shared.pdfToImages(pdfURL: url, format: fmt, destinationFolder: folder)
                    if let first = bridge.first {
                        job.status = .done(outputURL: first, note: "Extracted \(bridge.count) pages")
                    } else {
                        job.status = .failed("No pages extracted")
                    }
                }
            } else if let audioTarget = job.overrideAudioFormat ?? selectedAudioTarget {
                let res = try await aud.convert(
                    sourceURL: url,
                    to: audioTarget,
                    destinationFolder: dest,
                    targetSizeBytes: targetBytes,
                    preserveMetadata: preserveMetadata,
                    onProgress: { p in
                        DispatchQueue.main.async { job.updateProgress(p) }
                    }
                )
                job.status = .done(outputURL: res.outputURL)
            } else if let videoTarget = job.overrideVideoFormat ?? selectedVideoTarget {
                let res = try await vid.convert(
                    sourceURL: url,
                    to: videoTarget,
                    destinationFolder: dest,
                    targetSizeBytes: targetBytes,
                    targetWidth: targetWidth,
                    preserveMetadata: preserveMetadata,
                    onProgress: { p in
                        DispatchQueue.main.async { job.updateProgress(p) }
                    }
                )
                job.status = .done(outputURL: res.outputURL)
            } else if let imageTarget = job.overrideImageFormat ?? selectedImageTarget {
                let q = job.overrideQuality ?? quality
                let res = try await img.convert(
                    sourceURL: url,
                    to: imageTarget,
                    quality: q,
                    destinationFolder: dest,
                    targetSizeBytes: targetBytes,
                    targetWidth: targetWidth,
                    preserveMetadata: preserveMetadata
                )
                if let first = res.outputURLs.first {
                    job.status = .done(outputURL: first)
                } else {
                    job.status = .failed("No output generated")
                }
            } else if videoExtensions.contains(ext) {
                let res = try await vid.convert(
                    sourceURL: url,
                    to: .mp4H264,
                    destinationFolder: dest,
                    targetSizeBytes: targetBytes,
                    targetWidth: targetWidth,
                    preserveMetadata: preserveMetadata,
                    onProgress: { p in
                        DispatchQueue.main.async { job.updateProgress(p) }
                    }
                )
                job.status = .done(outputURL: res.outputURL)
            } else if audioExtensions.contains(ext) {
                let res = try await aud.convert(
                    sourceURL: url,
                    to: .mp3,
                    destinationFolder: dest,
                    targetSizeBytes: targetBytes,
                    preserveMetadata: preserveMetadata,
                    onProgress: { p in
                        DispatchQueue.main.async { job.updateProgress(p) }
                    }
                )
                job.status = .done(outputURL: res.outputURL)
            } else {
                let q = job.overrideQuality ?? quality
                let res = try await img.convert(
                    sourceURL: url,
                    to: .webp,
                    quality: q,
                    destinationFolder: dest,
                    targetSizeBytes: targetBytes,
                    targetWidth: targetWidth,
                    preserveMetadata: preserveMetadata
                )
                if let first = res.outputURLs.first {
                    job.status = .done(outputURL: first)
                } else {
                    job.status = .failed("No output generated")
                }
            }
        } catch {
            job.status = .failed(error.localizedDescription)
        }
    }
    
    private func executeAIRemoveBG() {
        let imageJobs = jobs.filter { imageExtensions.contains($0.sourceURL.pathExtension.lowercased()) }
        guard !imageJobs.isEmpty else { return }
        
        isConverting = true
        batchSummaryText = "AI removing backgrounds..."
        
        Task {
            for job in imageJobs {
                job.status = .converting(progress: 0.5, etaText: "AI isolating subject")
                do {
                    let out = try await BackgroundRemovalService.shared.removeBackground(from: job.sourceURL, destinationURL: effectiveDestinationFolder)
                    job.status = .done(outputURL: out)
                } catch {
                    job.status = .failed(error.localizedDescription)
                }
            }
            isConverting = false
            batchSummaryText = "AI background removal complete."
            if let firstDone = imageJobs.first, case .done(let out, _) = firstDone.status {
                self.comparisonSource = firstDone.sourceURL
                self.comparisonOutput = out
            }
        }
    }
    
    private func executeBurstPDF() {
        let pdfJobs = jobs.filter { $0.sourceURL.pathExtension.lowercased() == "pdf" }
        guard !pdfJobs.isEmpty else { return }
        
        isConverting = true
        batchSummaryText = "Bursting PDF pages..."
        
        Task {
            for job in pdfJobs {
                job.status = .converting(progress: 0.5, etaText: "Bursting pages")
                do {
                    let destFolder = effectiveDestinationFolder ?? job.sourceURL.deletingLastPathComponent().appendingPathComponent("\(job.sourceURL.deletingPathExtension().lastPathComponent)_burst")
                    let pages = try await PDFSplitService.shared.burst(source: job.sourceURL, destinationFolder: destFolder)
                    if let first = pages.first {
                        job.status = .done(outputURL: first, note: "Extracted \(pages.count) pages to folder")
                    }
                } catch {
                    job.status = .failed(error.localizedDescription)
                }
            }
            isConverting = false
            batchSummaryText = "Burst complete."
        }
    }
    
    // MARK: - Batch Renamer Modal Sheet
    
    private var renamerModalSheet: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "pencil.line")
                    .font(.title3.bold())
                Text("Batch Token Renamer")
                    .font(.headline)
                Spacer()
                Button("Done") { showRenamer = false }
                    .controlSize(.small)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Rename Template Pattern:")
                    .font(.caption.bold())
                    .foregroundStyle(TossyColor.textSecondary)
                
                TextField("Pattern", text: $renamePattern)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13, design: .monospaced))
                
                HStack(spacing: 6) {
                    tokenChip("{name}")
                    tokenChip("{date}")
                    tokenChip("{seq}")
                    tokenChip("{ext}")
                }
            }
            
            Picker("Case Transform", selection: $selectedCaseTransform) {
                ForEach(CaseTransform.allCases) { c in
                    Text(c.rawValue).tag(c)
                }
            }
            .pickerStyle(.segmented)
            
            // Preview
            if let first = jobs.first?.sourceURL {
                let previewName = TokenRenamer.shared.formatName(
                    fileURL: first,
                    pattern: renamePattern,
                    caseTransform: selectedCaseTransform,
                    index: 1
                )
                HStack {
                    Text("Preview:")
                        .font(.caption.bold())
                    Text("\(first.lastPathComponent) → \(previewName)")
                        .font(.caption.monospaced())
                        .foregroundStyle(TossyColor.textSecondary)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(TossyColor.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            
            HStack {
                Spacer()
                Button("Cancel") { showRenamer = false }
                    .buttonStyle(.bordered)
                Button("Apply Batch Rename") {
                    applyBatchRename()
                    showRenamer = false
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 480)
    }
    
    private func tokenChip(_ token: String) -> some View {
        Button {
            renamePattern += token
        } label: {
            Text(token)
                .font(.caption.monospaced())
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(TossyColor.surfaceElevated)
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(TossyColor.borderSubtle, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
    
    private func applyBatchRename() {
        var updated: [ConversionJob] = []
        for (index, job) in jobs.enumerated() {
            let url = job.sourceURL
            let newName = TokenRenamer.shared.formatName(
                fileURL: url,
                pattern: renamePattern,
                caseTransform: selectedCaseTransform,
                index: index + 1
            )
            let folder = url.deletingLastPathComponent()
            let newURL = folder.appendingPathComponent(newName)
            do {
                try FileManager.default.moveItem(at: url, to: newURL)
                updated.append(ConversionJob(sourceURL: newURL))
            } catch {
                updated.append(job)
            }
        }
        self.jobs = updated
        self.batchSummaryText = "Renamed \(updated.count) files successfully."
    }
}
