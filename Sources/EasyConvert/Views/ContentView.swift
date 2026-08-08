import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var jobs: [ConversionJob] = []
    @State private var selectedFormat: ImageFormat = .png
    @State private var quality: Double = 0.85
    @State private var destinationFolder: URL?
    @State private var isTargeted = false
    @State private var isConverting = false
    @State private var isShowingImporter = false
    @State private var keepOriginalFormat = false
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

    private let converter = ImageConverter()

    var body: some View {
        VStack(spacing: 0) {
            controlBar

            Divider()

            if jobs.isEmpty {
                DropZoneView(isTargeted: isTargeted) { isShowingImporter = true }
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
            allowedContentTypes: ImageFormat.readableContentTypes,
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
                    ForEach(ImageFormat.allCases) { format in
                        Text(format.isAvailable ? format.displayName : "\(format.displayName) (unavailable)")
                            .tag(format)
                    }
                }
                .frame(width: 260)
                .disabled(keepOriginalFormat)

                if selectedFormat.supportsQuality && !keepOriginalFormat {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Quality \(Int(quality * 100))%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Slider(value: $quality, in: 0.1...1.0)
                            .frame(width: 140)
                    }
                }

                Spacer()

                DestinationButton(destinationFolder: destinationFolder, action: chooseDestinationFolder)
            }

            DisclosureGroup("Advanced", isExpanded: $showAdvanced) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 16) {
                        Toggle("Keep original format (just recompress)", isOn: $keepOriginalFormat)
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
                            TextField("e.g. 1024, 512, 256", text: $resizeWidthText)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 160)
                        }

                        MaxFileSizeMenu()

                        PresetMenu(category: .image(
                            onApply: { preset in
                                if let fmt = ImageFormat(rawValue: preset.formatRawValue) { selectedFormat = fmt }
                                quality = preset.quality
                                keepOriginalFormat = preset.keepOriginalFormat
                                targetSizeText = preset.targetSizeText
                                customFilenameText = preset.customFilenameText
                                resizeWidthText = preset.resizeWidthText
                                preserveMetadata = preset.preserveMetadata
                            },
                            onSave: { name in
                                let preset = ImagePreset(
                                    name: name,
                                    formatRawValue: selectedFormat.rawValue,
                                    quality: quality,
                                    keepOriginalFormat: keepOriginalFormat,
                                    targetSizeText: targetSizeText,
                                    customFilenameText: customFilenameText,
                                    resizeWidthText: resizeWidthText,
                                    preserveMetadata: preserveMetadata
                                )
                                PresetStore.shared.imagePresets.append(preset)
                            }
                        ))

                        Spacer()
                    }

                    if exportWidths.count > 1 {
                        Text("Exports one file per width, suffixed \(exportWidths.map { "_\($0)" }.joined(separator: ", "))")
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

        await withTaskGroup(of: Void.self) { group in
            for job in pendingJobs {
                group.addTask {
                    await self.convert(job: job)
                }
            }
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

        var effectiveFormat = selectedFormat
        var formatNote: String?
        if keepOriginalFormat {
            if let matched = ImageFormat.matching(sourceURL: job.sourceURL), matched.isAvailable {
                effectiveFormat = matched
            } else {
                formatNote = "Couldn't match the original format — used \(selectedFormat.displayName) instead."
            }
        }

        guard effectiveFormat.isAvailable else {
            await MainActor.run { job.status = .failed(effectiveFormat.unavailabilityReason ?? "Unavailable format.") }
            return
        }
        await MainActor.run { job.status = .converting(progress: nil) }

        let baseName = customBaseName ?? job.sourceURL.deletingPathExtension().lastPathComponent
        do {
            if exportWidths.count > 1 {
                // Multi-resolution export: one output per width, each suffixed with its size.
                var firstOutput: URL?
                var succeededWidths: [Int] = []
                var lastFailure: String?
                for width in exportWidths {
                    do {
                        let result = try await converter.convert(
                            sourceURL: job.sourceURL,
                            to: effectiveFormat,
                            quality: quality,
                            destinationFolder: destinationFolder,
                            targetSizeBytes: targetSizeBytes,
                            targetWidth: width,
                            customBaseName: "\(baseName)_\(width)",
                            preserveMetadata: preserveMetadata
                        )
                        if firstOutput == nil { firstOutput = result.outputURLs.first }
                        succeededWidths.append(width)
                    } catch {
                        lastFailure = error.localizedDescription
                    }
                }
                if succeededWidths.isEmpty {
                    await MainActor.run { job.status = .failed(lastFailure ?? "All resolutions failed.") }
                    return
                }
                var note = "Exported \(succeededWidths.count) resolution\(succeededWidths.count == 1 ? "" : "s"): \(succeededWidths.map(String.init).joined(separator: ", "))"
                if succeededWidths.count < exportWidths.count {
                    note += ". Failed: \(lastFailure ?? "unknown error")"
                }
                if let formatNote { note = "\(formatNote) \(note)" }
                await MainActor.run { job.status = .done(outputURL: firstOutput ?? job.sourceURL, note: note) }
            } else {
                let result = try await converter.convert(
                    sourceURL: job.sourceURL,
                    to: effectiveFormat,
                    quality: quality,
                    destinationFolder: destinationFolder,
                    targetSizeBytes: targetSizeBytes,
                    targetWidth: exportWidths.first,
                    customBaseName: customBaseName,
                    preserveMetadata: preserveMetadata
                )
                let note = [formatNote, result.note].compactMap { $0 }.joined(separator: " ")
                await MainActor.run { job.status = .done(outputURL: result.outputURLs[0], note: note.isEmpty ? nil : note) }
            }
        } catch {
            await MainActor.run { job.status = .failed(error.localizedDescription) }
        }
    }
}
