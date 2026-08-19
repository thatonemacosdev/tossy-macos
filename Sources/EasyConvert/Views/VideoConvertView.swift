import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct VideoConvertView: View {
    @State private var jobs: [ConversionJob] = []
    @State private var selectedFormat: VideoFormat = .mp4H264
    @State private var destinationFolder: URL?
    @State private var isTargeted = false
    @State private var isConverting = false
    @State private var isShowingImporter = false
    @State private var isShowingInspector = false
    @State private var keepOriginalContainer = false
    @State private var targetSizeText = ""
    @State private var resizeWidthText = ""
    @State private var customFilenameText = ""
    @State private var showAdvanced = false
    @State private var preserveMetadata = true
    @State private var batchSummaryText: String?

    private var targetSizeBytes: Int64? { ByteSize.parse(targetSizeText) }
    private var exportWidths: [Int] { ResolutionList.parse(resizeWidthText) }
    private var customBaseName: String? {
        let trimmed = customFilenameText.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? nil : trimmed
    }

    private let converter = VideoConverter()

    var body: some View {
        VStack(spacing: 0) {
            controlBar

            Divider().overlay(TossyColor.borderSubtle)

            if jobs.isEmpty {
                DropZoneView(
                    isTargeted: isTargeted,
                    icon: "video.badge.arrow.down",
                    title: "Toss videos here to convert",
                    subtitle: "MP4, MOV, MKV, WebM, AVI, FLV, AV1, ProRes, Animated GIF, and more",
                    formatTags: ["MP4", "MOV", "MKV", "WebM", "AV1", "ProRes", "GIF"]
                ) { isShowingImporter = true }
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(jobs) { job in
                            JobRowView(
                                job: job,
                                categoryType: .video,
                                onRetry: {
                                    Task { await convert(job: job) }
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
            }

            Divider().overlay(TossyColor.borderSubtle)

            bottomBar
        }
        .frame(minWidth: 540, minHeight: 440)
        .background(TossyColor.pitchBlack)
        .onDrop(of: [.fileURL, .movie, .video, .data, .item], isTargeted: $isTargeted) { providers in
            handleDrop(providers)
        }
        .fileImporter(
            isPresented: $isShowingImporter,
            allowedContentTypes: VideoFormat.readableContentTypes,
            allowsMultipleSelection: true
        ) { result in
            if case .success(let urls) = result {
                addJobs(for: urls)
            }
        }
    }

    private var controlBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Picker("Convert to", selection: $selectedFormat) {
                    ForEach(VideoCategory.allCases, id: \.self) { category in
                        Section(category.rawValue) {
                            ForEach(VideoFormat.allCases.filter { $0.category == category }) { format in
                                Text(format.isAvailable ? format.displayName : "\(format.displayName) (unavailable)")
                                    .tag(format)
                            }
                        }
                    }
                }
                .frame(width: 250)
                .disabled(keepOriginalContainer)

                // Format Inspector Button
                Button {
                    isShowingInspector = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "slider.horizontal.3")
                        Text("Encoding Knobs")
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
                .help("Configure CRF, encoder speed presets, pixel format, and audio tracks")
                .popover(isPresented: $isShowingInspector) {
                    FormatInspectorView(category: .video(format: selectedFormat))
                }

                Spacer()

                DestinationButton(destinationFolder: effectiveDestinationFolder, action: chooseDestinationFolder)
            }

            DisclosureGroup("Advanced Options", isExpanded: $showAdvanced) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 16) {
                        Toggle("Keep original container (recompress in place)", isOn: $keepOriginalContainer)
                            .toggleStyle(.checkbox)

                        Toggle("Preserve metadata", isOn: $preserveMetadata)
                            .toggleStyle(.checkbox)

                        TargetSizeField(text: $targetSizeText)

                        Spacer()
                    }

                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Filename")
                                .font(.caption)
                                .foregroundStyle(TossyColor.textSecondary)
                            TextField("original name", text: $customFilenameText)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 120)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Export resolutions")
                                .font(.caption)
                                .foregroundStyle(TossyColor.textSecondary)
                            TextField("e.g. 1920, 1280, 854", text: $resizeWidthText)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 160)
                        }

                        MaxFileSizeMenu()

                        PresetMenu(category: .video(
                            onApply: { preset in
                                if let fmt = VideoFormat(rawValue: preset.formatRawValue) { selectedFormat = fmt }
                                keepOriginalContainer = preset.keepOriginalContainer
                                targetSizeText = preset.targetSizeText
                                customFilenameText = preset.customFilenameText
                                resizeWidthText = preset.resizeWidthText
                                preserveMetadata = preset.preserveMetadata
                            },
                            onSave: { name in
                                let preset = VideoPreset(
                                    name: name,
                                    formatRawValue: selectedFormat.rawValue,
                                    keepOriginalContainer: keepOriginalContainer,
                                    targetSizeText: targetSizeText,
                                    customFilenameText: customFilenameText,
                                    resizeWidthText: resizeWidthText,
                                    preserveMetadata: preserveMetadata
                                )
                                PresetStore.shared.videoPresets.append(preset)
                            }
                        ))

                        Spacer()
                    }

                    if exportWidths.count > 1 {
                        Text("One file per width, suffixed \(exportWidths.map { "_\($0)" }.joined(separator: ", "))")
                            .font(.caption)
                            .foregroundStyle(TossyColor.textTertiary)
                    }

                    if targetSizeBytes != nil || !exportWidths.isEmpty {
                        Text("Target size/resolution need an ffmpeg-backed format (not hardware presets)  -  bitrate is a single-pass estimate.")
                            .font(.caption)
                            .foregroundStyle(TossyColor.textTertiary)
                    }
                }
                .padding(.top, 6)
            }
        }
        .padding(14)
        .background(TossyColor.pitchBlack)
    }

    private var bottomBar: some View {
        HStack {
            if let batchSummaryText, !batchSummaryText.isEmpty {
                Text(batchSummaryText)
                    .font(.caption)
                    .foregroundStyle(TossyColor.textSecondary)
            } else if isConverting {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text("Encoding via VideoToolbox / ffmpeg (Threads: \(AppSettings.shared.maxConcurrentJobs))")
                        .font(.caption)
                        .foregroundStyle(TossyColor.textSecondary)
                }
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "film.stack")
                        .font(.system(size: 10))
                        .foregroundStyle(TossyColor.textTertiary)
                    Text("Engine: VideoToolbox Hardware / ffmpeg")
                        .font(.caption2)
                        .foregroundStyle(TossyColor.textTertiary)
                }
            }

            Spacer()

            if !jobs.isEmpty {
                Button("Add Files…") { isShowingImporter = true }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)

                Button("Clear") {
                    withAnimation(TossyMotion.springSmooth) {
                        jobs.removeAll()
                        batchSummaryText = nil
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .disabled(isConverting)
            }

            Button {
                Task { await convertAll() }
            } label: {
                if isConverting {
                    ProgressView().controlSize(.small)
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text(jobs.count > 1 ? "Convert All (\(jobs.count))" : "Convert")
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.white)
            .foregroundStyle(.black)
            .controlSize(.regular)
            .disabled(jobs.isEmpty || isConverting)
        }
        .padding(12)
        .background(TossyColor.surfaceDeep)
    }

    private var effectiveDestinationFolder: URL? {
        if let destinationFolder { return destinationFolder }
        if AppSettings.shared.destinationPolicy == .customFolder && !AppSettings.shared.customDestinationPath.isEmpty {
            return URL(fileURLWithPath: AppSettings.shared.customDestinationPath)
        }
        return nil
    }

    private func chooseDestinationFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        if panel.runModal() == .OK {
            destinationFolder = panel.url
        }
    }

    private func addJobs(for urls: [URL]) {
        let existing = Set(jobs.map(\.sourceURL))
        withAnimation(TossyMotion.springSmooth) {
            for url in urls where !existing.contains(url) {
                jobs.append(ConversionJob(sourceURL: url))
            }
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        var collected: [URL] = []
        let lock = NSLock()
        let group = DispatchGroup()

        for provider in providers {
            group.enter()

            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    var resolvedURL: URL? = nil
                    if let url = item as? URL {
                        resolvedURL = url
                    } else if let nsURL = item as? NSURL {
                        resolvedURL = nsURL as URL
                    } else if let data = item as? Data {
                        resolvedURL = URL(dataRepresentation: data, relativeTo: nil)
                    }

                    if let resolvedURL {
                        lock.lock()
                        collected.append(resolvedURL)
                        lock.unlock()
                        group.leave()
                    } else {
                        self.extractVideoData(from: provider, lock: lock) { url in
                            if let url {
                                lock.lock()
                                collected.append(url)
                                lock.unlock()
                            }
                            group.leave()
                        }
                    }
                }
            } else {
                self.extractVideoData(from: provider, lock: lock) { url in
                    if let url {
                        lock.lock()
                        collected.append(url)
                        lock.unlock()
                    }
                    group.leave()
                }
            }
        }

        group.notify(queue: .main) {
            addJobs(for: collected)
        }
        return true
    }

    private func extractVideoData(from provider: NSItemProvider, lock: NSLock, completion: @escaping (URL?) -> Void) {
        if provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
            provider.loadDataRepresentation(forTypeIdentifier: UTType.movie.identifier) { data, _ in
                if let data, let url = self.writeTempVideo(data: data, ext: "mov") {
                    completion(url)
                    return
                }
                completion(nil)
            }
        } else if provider.hasItemConformingToTypeIdentifier(UTType.video.identifier) {
            provider.loadDataRepresentation(forTypeIdentifier: UTType.video.identifier) { data, _ in
                if let data, let url = self.writeTempVideo(data: data, ext: "mp4") {
                    completion(url)
                    return
                }
                completion(nil)
            }
        } else if provider.hasItemConformingToTypeIdentifier(UTType.data.identifier) {
            provider.loadDataRepresentation(forTypeIdentifier: UTType.data.identifier) { data, _ in
                if let data, let url = self.writeTempVideo(data: data, ext: "mov") {
                    completion(url)
                    return
                }
                completion(nil)
            }
        } else {
            completion(nil)
        }
    }

    private func writeTempVideo(data: Data, ext: String) -> URL? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        let timestamp = formatter.string(from: Date())
        let filename = "Screen Recording \(timestamp) \(UUID().uuidString.prefix(4)).\(ext)"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do {
            try data.write(to: tempURL)
            return tempURL
        } catch {
            return nil
        }
    }

    private func convertAll() async {
        isConverting = true
        batchSummaryText = nil
        defer { isConverting = false }

        let pendingJobs = jobs.filter {
            if case .done = $0.status { return false }
            return true
        }

        for job in pendingJobs {
            await convert(job: job)
        }

        let summary = BatchSummary.summarize(jobs: jobs)
        batchSummaryText = summary
        BatchNotifier.notify(summary: summary, jobCount: pendingJobs.count)
    }

    private func convert(job: ConversionJob) async {
        await MainActor.run { job.resetProgress() }
        if let sizeWarning = FeasibilityChecker.checkFileSize(job.sourceURL) {
            await MainActor.run { job.status = .failed(sizeWarning) }
            return
        }

        let baseName = customBaseName ?? job.sourceURL.deletingPathExtension().lastPathComponent
        let widths: [Int?] = exportWidths.count > 1 ? exportWidths.map { $0 } : [exportWidths.first]
        let dest = effectiveDestinationFolder

        if keepOriginalContainer {
            guard let targetSizeBytes else {
                await MainActor.run { job.status = .failed("\"Keep original container\" needs a target size to compress toward  -  set one above.") }
                return
            }
            await MainActor.run { job.status = .converting(progress: 0) }

            var firstOutput: URL?
            var succeededWidths: [Int?] = []
            var lastFailure: String?
            for width in widths {
                let name = width.map { "\(baseName)_\($0)" } ?? baseName
                do {
                    let result = try await converter.compressKeepingContainer(
                        sourceURL: job.sourceURL,
                        destinationFolder: dest,
                        targetSizeBytes: targetSizeBytes,
                        targetWidth: width,
                        customBaseName: name,
                        preserveMetadata: preserveMetadata
                    ) { progress in
                        Task { @MainActor in job.updateProgress(progress) }
                    }
                    if firstOutput == nil { firstOutput = result.outputURL }
                    succeededWidths.append(width)
                } catch {
                    lastFailure = error.localizedDescription
                }
            }
            if succeededWidths.isEmpty {
                await MainActor.run { job.status = .failed(lastFailure ?? "All resolutions failed.") }
                return
            }
            var note = widths.count > 1 ? "Exported \(succeededWidths.count) of \(widths.count) resolutions" : nil
            if succeededWidths.count < widths.count {
                note = (note ?? "") + ". Failed: \(lastFailure ?? "unknown error")"
            }
            let finalURL = firstOutput ?? job.sourceURL
            await MainActor.run { job.status = .done(outputURL: finalURL, note: note) }
            handlePostConversion(sourceURL: job.sourceURL, outputURL: finalURL)
            return
        }

        let formatToUse = job.overrideVideoFormat ?? selectedFormat
        guard formatToUse.isAvailable else {
            await MainActor.run { job.status = .failed(formatToUse.unavailabilityReason ?? "Unavailable format.") }
            return
        }
        await MainActor.run { job.status = .converting(progress: 0) }

        var firstOutput: URL?
        var lastNote: String?
        var succeededWidths: [Int?] = []
        var lastFailure: String?
        for width in widths {
            let name: String? = width.map { "\(baseName)_\($0)" } ?? customBaseName
            do {
                let result = try await converter.convert(
                    sourceURL: job.sourceURL,
                    to: formatToUse,
                    destinationFolder: dest,
                    targetSizeBytes: targetSizeBytes,
                    targetWidth: width,
                    customBaseName: name,
                    preserveMetadata: preserveMetadata
                ) { progress in
                    Task { @MainActor in job.updateProgress(progress) }
                }
                if firstOutput == nil { firstOutput = result.outputURL }
                lastNote = result.note
                succeededWidths.append(width)
            } catch {
                lastFailure = error.localizedDescription
            }
        }
        if succeededWidths.isEmpty {
            await MainActor.run { job.status = .failed(lastFailure ?? "All resolutions failed.") }
            return
        }
        var note = widths.count > 1
            ? "Exported \(succeededWidths.count) of \(widths.count) resolutions"
            : lastNote
        if succeededWidths.count < widths.count {
            note = (note ?? "") + ". Failed: \(lastFailure ?? "unknown error")"
        }
        let finalURL = firstOutput ?? job.sourceURL
        await MainActor.run { job.status = .done(outputURL: finalURL, note: note) }
        handlePostConversion(sourceURL: job.sourceURL, outputURL: finalURL)
    }

    private func handlePostConversion(sourceURL: URL, outputURL: URL) {
        if AppSettings.shared.autoRevealInFinder {
            NSWorkspace.shared.activateFileViewerSelecting([outputURL])
        }
        if AppSettings.shared.deleteSourceAfterConversion && sourceURL != outputURL {
            try? FileManager.default.removeItem(at: sourceURL)
        }
    }
}
