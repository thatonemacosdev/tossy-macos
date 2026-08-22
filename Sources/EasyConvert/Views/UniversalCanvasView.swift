import SwiftUI
import UniformTypeIdentifiers

struct UniversalCanvasView: View {
    @State private var droppedURLs: [URL] = []
    @State private var selectedURLs: Set<URL> = []
    @State private var isTargeted = false
    
    // Modal states
    @State private var showPDFStudio = false
    @State private var showMediaStudio = false
    @State private var showArchiveModal = false
    @State private var showCodeCards = false
    @State private var showMetadataSanitizer = false
    
    @State private var isProcessing = false
    @State private var progress: Double = 0.0
    @State private var statusMessage: String?
    @State private var completedOutputs: [URL] = []
    
    // Batch renamer sheet state
    @State private var showRenamer = false
    @State private var renamePattern = "{name}_v2"
    @State private var selectedCaseTransform: CaseTransform = .original
    
    private var effectiveURLs: [URL] {
        if selectedURLs.isEmpty {
            return droppedURLs
        } else {
            return droppedURLs.filter { selectedURLs.contains($0) }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if droppedURLs.isEmpty {
                emptyCanvasDropzone
            } else {
                activeCanvasWorkspace
            }
        }
        .sheet(isPresented: $showPDFStudio) {
            PDFStudioModalView(sourceURLs: effectiveURLs)
        }
        .sheet(isPresented: $showMediaStudio) {
            MediaStudioModalView(sourceURLs: effectiveURLs)
        }
        .sheet(isPresented: $showArchiveModal) {
            ArchiveOptionsModalView(sourceURLs: effectiveURLs) { output in
                completedOutputs.append(output)
                statusMessage = "Created archive: \(output.lastPathComponent)"
            }
        }
        .sheet(isPresented: $showCodeCards) {
            CodeCardModalView()
        }
        .sheet(isPresented: $showMetadataSanitizer) {
            EXIFSanitizerModalView(sourceURLs: effectiveURLs)
        }
        .sheet(isPresented: $showRenamer) {
            renamerModalSheet
        }
    }
    
    // Empty state dropzone
    private var emptyCanvasDropzone: some View {
        VStack(spacing: 20) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(isTargeted ? Color.accentColor.opacity(0.2) : Color(nsColor: .controlBackgroundColor))
                    .frame(width: 140, height: 140)
                    .scaleEffect(isTargeted ? 1.08 : 1.0)
                    .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isTargeted)
                
                Image(systemName: isTargeted ? "arrow.down.circle.fill" : "rectangle.stack.fill")
                    .font(.system(size: 54))
                    .foregroundStyle(isTargeted ? Color.accentColor : .secondary)
            }
            
            VStack(spacing: 8) {
                Text("Universal File Canvas")
                    .font(.title2.bold())
                
                Text("Drop any image, video, audio, PDF, code, or archive to begin")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            HStack(spacing: 12) {
                quickBadge(label: "PDF Merge & OCR", icon: "doc.richtext")
                quickBadge(label: "Lossless Trimming", icon: "scissors")
                quickBadge(label: "AI Remove BG", icon: "person.crop.circle")
                quickBadge(label: "Encrypted Archive", icon: "lock.shield")
                quickBadge(label: "Code Cards", icon: "curlybraces.square")
            }
            .padding(.top, 8)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(isTargeted ? Color.accentColor : Color.secondary.opacity(0.2), style: StrokeStyle(lineWidth: 2, dash: [8]))
                .padding(24)
        )
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            handleDroppedProviders(providers)
            return true
        }
    }
    
    // Active workspace with files
    private var activeCanvasWorkspace: some View {
        VStack(spacing: 0) {
            // Top Bar
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text("\(droppedURLs.count) Item(s) on Canvas")
                            .font(.headline)
                        
                        if !selectedURLs.isEmpty {
                            Text("(\(selectedURLs.count) selected)")
                                .font(.subheadline)
                                .foregroundStyle(.tint)
                        }
                    }
                    Text(summaryString)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Multi-selection actions
                if !droppedURLs.isEmpty {
                    Button(selectedURLs.count == droppedURLs.count ? "Deselect All" : "Select All") {
                        if selectedURLs.count == droppedURLs.count {
                            selectedURLs.removeAll()
                        } else {
                            selectedURLs = Set(droppedURLs)
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .padding(.trailing, 8)
                }
                
                if !selectedURLs.isEmpty {
                    Button("Remove Selected") {
                        withAnimation {
                            droppedURLs.removeAll { selectedURLs.contains($0) }
                            selectedURLs.removeAll()
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.red)
                    .padding(.trailing, 8)
                }
                
                Button("Clear Canvas") {
                    withAnimation {
                        droppedURLs.removeAll()
                        selectedURLs.removeAll()
                        completedOutputs.removeAll()
                        statusMessage = nil
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .padding(.trailing, 8)
                
                Button {
                    showRenamer = true
                } label: {
                    Label("Batch Rename", systemImage: "pencil.line")
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .background(Color(nsColor: .windowBackgroundColor))
            
            Divider()
            
            // File List & Studio Cards
            ScrollView {
                VStack(spacing: 16) {
                    // Studio Tool Action Cards
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 180))], spacing: 12) {
                        studioActionCard(
                            title: "PDF Studio",
                            subtitle: "Merge, Split, OCR, Compress",
                            icon: "doc.richtext",
                            color: .red
                        ) {
                            showPDFStudio = true
                        }
                        
                        studioActionCard(
                            title: "Media Studio",
                            subtitle: "Lossless Trim, Audio Strip, Speed",
                            icon: "film.stack",
                            color: .purple
                        ) {
                            showMediaStudio = true
                        }
                        
                        studioActionCard(
                            title: "Archive Suite",
                            subtitle: "Encrypted ZIP, Volumes, Unpack",
                            icon: "archivebox.fill",
                            color: .orange
                        ) {
                            showArchiveModal = true
                        }
                        
                        studioActionCard(
                            title: "Code Cards",
                            subtitle: "Carbon Syntax PNG Snippets",
                            icon: "curlybraces.square.fill",
                            color: .blue
                        ) {
                            showCodeCards = true
                        }
                        
                        studioActionCard(
                            title: "EXIF Sanitizer",
                            subtitle: "Strip GPS, Hardware & Timestamps",
                            icon: "eye.slash.fill",
                            color: .indigo
                        ) {
                            showMetadataSanitizer = true
                        }
                    }
                    
                    // Queued Items Table
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Queued Files")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("Click checkbox or row to select")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        
                        ForEach(droppedURLs, id: \.self) { url in
                            let isSelected = selectedURLs.contains(url)
                            HStack {
                                Button {
                                    toggleSelection(url)
                                } label: {
                                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                                }
                                .buttonStyle(.plain)
                                
                                Image(systemName: iconForURL(url))
                                    .foregroundStyle(.tint)
                                
                                Text(url.lastPathComponent)
                                    .font(.body)
                                
                                Spacer()
                                
                                if let size = try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64 {
                                    Text(ByteSize.displayString(size))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Button {
                                    withAnimation {
                                        droppedURLs.removeAll { $0 == url }
                                        selectedURLs.remove(url)
                                    }
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(isSelected ? Color.accentColor.opacity(0.12) : Color(nsColor: .controlBackgroundColor))
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                toggleSelection(url)
                            }
                        }
                    }
                }
                .padding()
            }
            
            Divider()
            
            // Output status bar
            if isProcessing || statusMessage != nil || !completedOutputs.isEmpty {
                HStack {
                    if isProcessing {
                        ProgressView(value: progress)
                            .progressViewStyle(.linear)
                            .frame(width: 140)
                    }
                    
                    if let statusMessage {
                        Text(statusMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    if !completedOutputs.isEmpty {
                        Button("Show in Finder") {
                            NSWorkspace.shared.activateFileViewerSelecting(completedOutputs)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding()
                .background(Color(nsColor: .windowBackgroundColor))
            }
        }
        // Sequential Drag and Drop support on active workspace
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            handleDroppedProviders(providers)
            return true
        }
    }
    
    private func toggleSelection(_ url: URL) {
        if selectedURLs.contains(url) {
            selectedURLs.remove(url)
        } else {
            selectedURLs.insert(url)
        }
    }
    
    private func quickBadge(label: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
            Text(label)
                .font(.caption.bold())
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(Color(nsColor: .controlBackgroundColor)))
    }
    
    private func studioActionCard(title: String, subtitle: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundStyle(color)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                }
                
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .controlBackgroundColor)))
        }
        .buttonStyle(.plain)
    }
    
    private var summaryString: String {
        let exts = Set(droppedURLs.map { $0.pathExtension.uppercased() }).joined(separator: ", ")
        return "Formats: \(exts)"
    }
    
    private func iconForURL(_ url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        if ["png", "jpg", "jpeg", "heic", "webp", "gif", "svg", "jxl", "avif"].contains(ext) { return "photo.fill" }
        if ["mov", "mp4", "m4v", "mkv", "webm", "avi"].contains(ext) { return "video.fill" }
        if ["mp3", "m4a", "wav", "flac", "aac", "ogg"].contains(ext) { return "waveform" }
        if ext == "pdf" { return "doc.richtext" }
        if ["zip", "tar", "gz", "7z", "rar"].contains(ext) { return "archivebox.fill" }
        if ["swift", "py", "js", "ts", "rs", "go", "json", "html", "css", "md"].contains(ext) { return "curlybraces.square" }
        return "doc.fill"
    }
    
    private func handleDroppedProviders(_ providers: [NSItemProvider]) {
        for provider in providers {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url else { return }
                DispatchQueue.main.async {
                    if !self.droppedURLs.contains(url) {
                        self.droppedURLs.append(url)
                    }
                }
            }
        }
    }
    
    private var renamerModalSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Batch Token Renamer")
                .font(.headline)
            
            Text("Available tokens: {name}, {ext}, {date}, {time}, {year}, {counter:3}")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            TextField("Rename Pattern", text: $renamePattern)
                .textFieldStyle(.roundedBorder)
            
            Picker("Case Transform", selection: $selectedCaseTransform) {
                ForEach(CaseTransform.allCases) { transform in
                    Text(transform.rawValue).tag(transform)
                }
            }
            
            HStack {
                Button("Cancel") {
                    showRenamer = false
                }
                Spacer()
                Button("Apply Batch Rename (\(effectiveURLs.count) items)") {
                    showRenamer = false
                    applyRename()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(minWidth: 440)
    }
    
    private func applyRename() {
        do {
            let renamed = try TokenRenamer.shared.applyBatchRename(
                urls: effectiveURLs,
                pattern: renamePattern,
                caseTransform: selectedCaseTransform
            )
            // Replace renamed in droppedURLs
            var newDropped = droppedURLs
            for (idx, original) in effectiveURLs.enumerated() {
                if let pos = newDropped.firstIndex(of: original), idx < renamed.count {
                    newDropped[pos] = renamed[idx]
                }
            }
            droppedURLs = newDropped
            selectedURLs.removeAll()
            completedOutputs = renamed
            statusMessage = "Renamed \(renamed.count) files successfully."
        } catch {
            statusMessage = "Rename error: \(error.localizedDescription)"
        }
    }
}
