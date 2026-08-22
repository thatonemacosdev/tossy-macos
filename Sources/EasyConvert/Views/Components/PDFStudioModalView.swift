import SwiftUI
import PDFKit

struct PDFStudioModalView: View {
    let sourceURLs: [URL]
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedTab: PDFStudioTab = .merge
    @State private var isProcessing = false
    @State private var progress: Double = 0.0
    @State private var statusMessage: String?
    @State private var outputURL: URL?
    @State private var splitOutputs: [URL] = []
    
    // Merge / Reorder state
    @State private var selectedDocuments: [URL] = []
    
    // Split state
    @State private var splitMode: SplitMode = .ranges
    @State private var splitRangeText: String = "1-3, 4-7"
    
    // Compress state
    @State private var selectedPreset: PDFCompressionPreset = .medium
    @State private var targetSizeMB: String = ""
    @State private var compressionResult: PDFCompressionResult?
    
    // OCR state
    @State private var ocrResultText: String = ""
    
    enum SplitMode: String, CaseIterable, Identifiable {
        case ranges = "Custom Page Ranges"
        case burst = "Burst All Pages"
        
        var id: String { rawValue }
    }
    
    enum PDFStudioTab: String, CaseIterable, Identifiable {
        case merge = "Merge & Reorder"
        case split = "Split & Burst"
        case compress = "Compress PDF"
        case ocr = "Vision OCR"
        case bridge = "PDF to Images"
        
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .merge: return "doc.on.doc.fill"
            case .split: return "scissors"
            case .compress: return "arrow.down.right.and.arrow.up.left"
            case .ocr: return "text.viewfinder"
            case .bridge: return "photo.stack"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "doc.richtext")
                    .font(.title2)
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text("PDF & Document Studio")
                        .font(.headline)
                    Text("\(sourceURLs.count) document(s) loaded")
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
                ForEach(PDFStudioTab.allCases) { tab in
                    Label(tab.rawValue, systemImage: tab.icon).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding()
            
            // Tab Content
            ScrollView {
                VStack(spacing: 16) {
                    switch selectedTab {
                    case .merge:
                        mergeView
                    case .split:
                        splitView
                    case .compress:
                        compressView
                    case .ocr:
                        ocrView
                    case .bridge:
                        bridgeView
                    }
                }
                .padding(.horizontal)
            }
            
            Divider()
            
            // Footer
            HStack {
                if isProcessing {
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                        .frame(maxWidth: 200)
                    Text("\(Int(progress * 100))%")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                } else if let statusMessage {
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                if let outputURL {
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
        .frame(minWidth: 640, minHeight: 500)
        .onAppear {
            selectedDocuments = sourceURLs
        }
    }
    
    private var actionButtonTitle: String {
        switch selectedTab {
        case .merge: return "Merge PDFs"
        case .split: return splitMode == .ranges ? "Extract Ranges" : "Burst All Pages"
        case .compress: return "Compress PDF"
        case .ocr: return "Extract Text"
        case .bridge: return "Export Images"
        }
    }
    
    private var mergeView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Combine multiple PDF documents into a single unified file:")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            ForEach(selectedDocuments, id: \.self) { doc in
                HStack {
                    Image(systemName: "doc.fill")
                        .foregroundStyle(.red)
                    Text(doc.lastPathComponent)
                        .font(.body)
                    Spacer()
                    Text(doc.pathExtension.uppercased())
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color(nsColor: .controlBackgroundColor)))
            }
        }
    }
    
    private var splitView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Split or burst pages from PDF document:")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Picker("Split Mode", selection: $splitMode) {
                ForEach(SplitMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            
            if splitMode == .ranges {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Enter comma-separated page numbers or ranges (e.g. 1-3, 5, 8-10):")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    TextField("1-3, 5, 8-10", text: $splitRangeText)
                        .textFieldStyle(.roundedBorder)
                }
            } else {
                Text("Every page in the document will be extracted into a standalone single-page PDF.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            if !splitOutputs.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Generated Parts (\(splitOutputs.count)):")
                        .font(.caption.bold())
                    
                    ForEach(splitOutputs.prefix(5), id: \.self) { url in
                        Text(url.lastPathComponent)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                    if splitOutputs.count > 5 {
                        Text("+ \(splitOutputs.count - 5) more files")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color(nsColor: .controlBackgroundColor)))
            }
        }
    }
    
    private var compressView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Select compression preset:")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Picker("Compression Preset", selection: $selectedPreset) {
                ForEach(PDFCompressionPreset.allCases) { preset in
                    Text(preset.rawValue).tag(preset)
                }
            }
            .pickerStyle(.radioGroup)
            
            if let compressionResult {
                HStack {
                    Text("Original: \(ByteSize.displayString(compressionResult.originalSizeBytes))")
                    Image(systemName: "arrow.right")
                    Text("Compressed: \(ByteSize.displayString(compressionResult.compressedSizeBytes))")
                    Text("(\(String(format: "%.1f", compressionResult.savingsRatioPercent))% saved)")
                        .bold()
                        .foregroundStyle(.green)
                }
                .font(.subheadline)
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.green.opacity(0.1)))
            }
        }
    }
    
    private var ocrView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("On-device Apple Vision Optical Character Recognition:")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            if !ocrResultText.isEmpty {
                TextEditor(text: .constant(ocrResultText))
                    .font(.system(.body, design: .monospaced))
                    .frame(height: 200)
                    .background(Color(nsColor: .textBackgroundColor))
                    .cornerRadius(6)
            }
        }
    }
    
    private var bridgeView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Export each page of the document as high-resolution PNG images.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
    
    private func executeAction() {
        guard let first = sourceURLs.first else { return }
        isProcessing = true
        statusMessage = "Processing..."
        progress = 0.1
        
        let destinationFolder = first.deletingLastPathComponent()
        let baseName = first.deletingPathExtension().lastPathComponent
        
        Task {
            do {
                switch selectedTab {
                case .merge:
                    let desired = destinationFolder.appendingPathComponent("\(baseName)_merged.pdf")
                    let res = try await PDFMergeService.shared.merge(documents: sourceURLs, destination: desired) { p in
                        DispatchQueue.main.async { self.progress = p }
                    }
                    await MainActor.run {
                        self.outputURL = res
                        self.statusMessage = "Merged \(sourceURLs.count) PDFs successfully."
                        self.isProcessing = false
                    }
                case .split:
                    if splitMode == .ranges {
                        guard let doc = PDFDocument(url: first) else {
                            throw PDFServiceError.unreadableDocument(first)
                        }
                        let parsedRanges = PDFSplitService.shared.parsePageRanges(text: splitRangeText, totalPages: doc.pageCount)
                        guard !parsedRanges.isEmpty else {
                            throw PDFServiceError.invalidPageRange("Please enter valid page ranges like 1-5, 8")
                        }
                        let desiredFolder = destinationFolder.appendingPathComponent("\(baseName)_split_ranges")
                        let safeFolder = OutputNaming.uniqueFolderURL(desiredFolderURL: desiredFolder)
                        let res = try await PDFSplitService.shared.splitByRanges(source: first, ranges: parsedRanges, destinationFolder: safeFolder)
                        await MainActor.run {
                            self.splitOutputs = res
                            self.outputURL = res.first ?? safeFolder
                            self.statusMessage = "Extracted \(res.count) part(s) to folder: \(safeFolder.lastPathComponent)"
                            self.isProcessing = false
                        }
                    } else {
                        let desiredFolder = destinationFolder.appendingPathComponent("\(baseName)_split_pages")
                        let safeFolder = OutputNaming.uniqueFolderURL(desiredFolderURL: desiredFolder)
                        let res = try await PDFSplitService.shared.burst(source: first, destinationFolder: safeFolder) { p in
                            DispatchQueue.main.async { self.progress = p }
                        }
                        await MainActor.run {
                            self.splitOutputs = res
                            self.outputURL = res.first ?? safeFolder
                            self.statusMessage = "Bursted \(res.count) single pages to folder: \(safeFolder.lastPathComponent)"
                            self.isProcessing = false
                        }
                    }
                case .compress:
                    let desired = destinationFolder.appendingPathComponent("\(baseName)_compressed.pdf")
                    let res = try await PDFCompressService.shared.compress(source: first, preset: selectedPreset, destination: desired) { p in
                        DispatchQueue.main.async { self.progress = p }
                    }
                    await MainActor.run {
                        self.compressionResult = res
                        self.outputURL = res.outputURL
                        self.statusMessage = "Compressed successfully."
                        self.isProcessing = false
                    }
                case .ocr:
                    let res = try await VisionOCRService.shared.extractText(from: first)
                    let desiredTextURL = destinationFolder.appendingPathComponent("\(baseName)_ocr.txt")
                    let safeTextURL = OutputNaming.uniqueDestinationURL(desiredURL: desiredTextURL)
                    _ = try await VisionOCRService.shared.exportToTextFile(from: first, destinationURL: safeTextURL)
                    await MainActor.run {
                        self.ocrResultText = res.combinedText
                        self.outputURL = safeTextURL
                        self.statusMessage = "Extracted \(res.totalWordCount) words."
                        self.isProcessing = false
                    }
                case .bridge:
                    let desiredImgFolder = destinationFolder.appendingPathComponent("\(baseName)_images")
                    let safeImgFolder = OutputNaming.uniqueFolderURL(desiredFolderURL: desiredImgFolder)
                    let res = try await DocImageBridgeService.shared.pdfToImages(pdfURL: first, format: .png, dpi: 200, destinationFolder: safeImgFolder) { p in
                        DispatchQueue.main.async { self.progress = p }
                    }
                    await MainActor.run {
                        self.outputURL = res.first ?? safeImgFolder
                        self.statusMessage = "Exported \(res.count) image pages to folder."
                        self.isProcessing = false
                    }
                }
            } catch {
                await MainActor.run {
                    self.statusMessage = "Error: \(error.localizedDescription)"
                    self.isProcessing = false
                }
            }
        }
    }
}
