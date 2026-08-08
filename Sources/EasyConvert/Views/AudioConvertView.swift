import SwiftUI
import UniformTypeIdentifiers

struct AudioConvertView: View {
    @State private var jobs: [ConversionJob] = []
    @State private var selectedFormat: AudioFormat = .mp3
    @State private var quality: Double = 0.7
    @State private var destinationFolder: URL?
    @State private var isTargeted = false
    @State private var isConverting = false
    @State private var isShowingImporter = false
    @State private var keepOriginalFormat = false
    @State private var targetSizeText = ""
    @State private var customFilenameText = ""
    @State private var showAdvanced = false
    @State private var preserveMetadata = true
    @State private var batchSummaryText: String?

    private var targetSizeBytes: Int64? { ByteSize.parse(targetSizeText) }
    private var customBaseName: String? {
        let trimmed = customFilenameText.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? nil : trimmed
    }

    private let converter = AudioConverter()

    var body: some View {
        VStack(spacing: 0) {
            controlBar

            Divider()

            if jobs.isEmpty {
                DropZoneView(
                    isTargeted: isTargeted,
                    icon: "waveform.badge.arrow.down",
                    title: "Toss audio here to convert",
                    subtitle: "MP3, AAC, WAV, FLAC, ALAC, OGG, Opus, WMA, AC3, and more"
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
            allowedContentTypes: AudioFormat.readableContentTypes,
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
                    ForEach(AudioFormat.allCases) { format in
                        Text(format.isAvailable ? format.displayName : "\(format.displayName) (unavailable)")
                            .tag(format)
                    }
                }
                .frame(width: 240)
                .disabled(keepOriginalFormat)

                if selectedFormat.supportsQuality && !keepOriginalFormat {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Bitrate \(Int(64 + quality * 192))kbps")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Slider(value: $quality, in: 0...1)
                            .frame(width: 140)
                    }
                }

                Spacer()

                DestinationButton(destinationFolder: destinationFolder, action: chooseDestinationFolder)
            }

            DisclosureGroup("Advanced", isExpanded: $showAdvanced) {
                HStack(spacing: 16) {
                    Toggle("Keep original format (just recompress)", isOn: $keepOriginalFormat)
                        .toggleStyle(.checkbox)

                    Toggle("Preserve original metadata", isOn: $preserveMetadata)
                        .toggleStyle(.checkbox)

                    TargetSizeField(text: $targetSizeText)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Filename")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("original name", text: $customFilenameText)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 120)
                    }

                    MaxFileSizeMenu()

                    PresetMenu(category: .audio(
                        onApply: { preset in
                            if let fmt = AudioFormat(rawValue: preset.formatRawValue) { selectedFormat = fmt }
                            quality = preset.quality
                            keepOriginalFormat = preset.keepOriginalFormat
                            targetSizeText = preset.targetSizeText
                            customFilenameText = preset.customFilenameText
                            preserveMetadata = preset.preserveMetadata
                        },
                        onSave: { name in
                            let preset = AudioPreset(
                                name: name,
                                formatRawValue: selectedFormat.rawValue,
                                quality: quality,
                                keepOriginalFormat: keepOriginalFormat,
                                targetSizeText: targetSizeText,
                                customFilenameText: customFilenameText,
                                preserveMetadata: preserveMetadata
                            )
                            PresetStore.shared.audioPresets.append(preset)
                        }
                    ))

                    Spacer()
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
            .tint(.white)
            .foregroundStyle(.black)
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

        var effectiveFormat = selectedFormat
        var formatNote: String?
        if keepOriginalFormat {
            if let matched = AudioFormat.matching(sourceURL: job.sourceURL), matched.isAvailable {
                effectiveFormat = matched
            } else {
                formatNote = "Couldn't match the original format — used \(selectedFormat.displayName) instead."
            }
        }

        guard effectiveFormat.isAvailable else {
            await MainActor.run { job.status = .failed(effectiveFormat.unavailabilityReason ?? "Unavailable format.") }
            return
        }
        await MainActor.run { job.status = .converting(progress: 0) }
        do {
            let result = try await converter.convert(
                sourceURL: job.sourceURL,
                to: effectiveFormat,
                quality: quality,
                destinationFolder: destinationFolder,
                targetSizeBytes: targetSizeBytes,
                customBaseName: customBaseName,
                preserveMetadata: preserveMetadata
            ) { progress in
                Task { @MainActor in job.updateProgress(progress) }
            }
            let note = [formatNote, result.note].compactMap { $0 }.joined(separator: " ")
            await MainActor.run { job.status = .done(outputURL: result.outputURL, note: note.isEmpty ? nil : note) }
        } catch {
            await MainActor.run { job.status = .failed(error.localizedDescription) }
        }
    }
}
