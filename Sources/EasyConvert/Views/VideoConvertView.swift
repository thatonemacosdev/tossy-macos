import SwiftUI
import UniformTypeIdentifiers

struct VideoConvertView: View {
    @State private var jobs: [ConversionJob] = []
    @State private var selectedFormat: VideoFormat = .mp4H264
    @State private var destinationFolder: URL?
    @State private var isTargeted = false
    @State private var isConverting = false
    @State private var isShowingImporter = false
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

            Divider()

            if jobs.isEmpty {
                DropZoneView(
                    isTargeted: isTargeted,
                    icon: "video.badge.arrow.down",
                    title: "Toss videos here to convert",
                    subtitle: "MP4, MOV, MKV, WebM, AVI, FLV, Animated GIF, and more"
                ) { isShowingImporter = true }
            } else {
                List(jobs) { job in
                    JobRowView(job: job, onRetry: {
                        Task { await convert(job: job) }
                    })
                }
                .listStyle(.inset)
            }

            Divider()

            bottomBar
        }
        .frame(minWidth: 520, minHeight: 420)
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
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
            HStack(spacing: 16) {
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
                .frame(width: 260)
                .disabled(keepOriginalContainer)

                Spacer()

                DestinationButton(destinationFolder: destinationFolder, action: chooseDestinationFolder)
            }

            DisclosureGroup("Advanced", isExpanded: $showAdvanced) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 16) {
                        Toggle("Keep original container (just recompress)", isOn: $keepOriginalContainer)
                            .toggleStyle(.checkbox)

                        Toggle("Preserve original metadata", isOn: $preserveMetadata)
                            .toggleStyle(.checkbox)

                        TargetSizeField(text: $targetSizeText)

                        Spacer()
                    }

                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Filename")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            TextField("original name", text: $customFilenameText)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 120)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Export resolutions")
                                .font(.caption)
                                .foregroundStyle(.secondary)
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
                            .foregroundStyle(.secondary)
                    }

                    if targetSizeBytes != nil || !exportWidths.isEmpty {
                        Text("Target size/resolution need an ffmpeg-backed format (not the hardware-accelerated MP4/MOV presets) — bitrate is a single-pass estimate, not exact.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 6)
            }
        }
        .padding(12)
    }

    private var bottomBar: some View {
        HStack {
            if let batchSummaryText, !batchSummaryText.isEmpty {
                Text(batchSummaryText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if !jobs.isEmpty {
                Button("Add Files…") { isShowingImporter = true }
                Button("Clear") {
                    jobs.removeAll()
                    batchSummaryText = nil
                }
                .disabled(isConverting)
            }

            Button {
                Task { await convertAll() }
            } label: {
                if isConverting {
                    ProgressView().controlSize(.small)
                } else {
                    Text("Convert All")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(jobs.isEmpty || isConverting)
        }
        .padding(12)
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
        for url in urls where !existing.contains(url) {
            jobs.append(ConversionJob(sourceURL: url))
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        var collected: [URL] = []
        let group = DispatchGroup()

        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                defer { group.leave() }
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                collected.append(url)
            }
        }

        group.notify(queue: .main) {
            addJobs(for: collected)
        }
        return true
    }

    private func convertAll() async {
        isConverting = true
        batchSummaryText = nil
        defer { isConverting = false }

        let pendingJobs = jobs.filter {
            if case .done = $0.status { return false }
            return true
        }

        // Video transcodes are already hardware-parallelized internally by VideoToolbox;
        // running them one at a time avoids the encoders contending with each other.
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

        if keepOriginalContainer {
            guard let targetSizeBytes else {
                await MainActor.run { job.status = .failed("\"Keep original container\" needs a target size to compress toward — set one above.") }
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
                        destinationFolder: destinationFolder,
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
            await MainActor.run { job.status = .done(outputURL: firstOutput ?? job.sourceURL, note: note) }
            return
        }

        guard selectedFormat.isAvailable else {
            await MainActor.run { job.status = .failed(selectedFormat.unavailabilityReason ?? "Unavailable format.") }
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
                    to: selectedFormat,
                    destinationFolder: destinationFolder,
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
        await MainActor.run { job.status = .done(outputURL: firstOutput ?? job.sourceURL, note: note) }
    }
}
