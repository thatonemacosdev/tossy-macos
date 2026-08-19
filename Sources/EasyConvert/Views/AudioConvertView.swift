import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct AudioConvertView: View {
    @State private var jobs: [ConversionJob] = []
    @State private var selectedFormat: AudioFormat = .mp3
    @State private var quality: Double = 0.7
    @State private var destinationFolder: URL?
    @State private var isTargeted = false
    @State private var isConverting = false
    @State private var isShowingImporter = false
    @State private var isShowingInspector = false
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

            Divider().overlay(TossyColor.borderSubtle)

            if jobs.isEmpty {
                DropZoneView(
                    isTargeted: isTargeted,
                    icon: "waveform.badge.arrow.down",
                    title: "Toss audio here to convert",
                    subtitle: "MP3, AAC, FLAC, WAV, ALAC, OGG, Opus, WMA, AC3  -  or drop a video to extract audio",
                    formatTags: ["MP3", "AAC", "FLAC", "WAV", "ALAC", "Opus", "OGG"]
                ) { isShowingImporter = true }
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(jobs) { job in
                            JobRowView(
                                job: job,
                                categoryType: .audio,
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
            HStack(spacing: 12) {
                Picker("Convert to", selection: $selectedFormat) {
                    ForEach(AudioFormat.allCases) { format in
                        Text(format.isAvailable ? format.displayName : "\(format.displayName) (unavailable)")
                            .tag(format)
                    }
                }
                .frame(width: 230)
                .disabled(keepOriginalFormat)

                // Format Inspector Button
                Button {
                    isShowingInspector = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "slider.horizontal.3")
                        Text("Audio Knobs")
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
                .help("Configure CBR/VBR, sample rates, channels, bit depth, and EBU R128 normalization")
                .popover(isPresented: $isShowingInspector) {
                    FormatInspectorView(category: .audio(format: selectedFormat))
                }

                if selectedFormat.supportsQuality && !keepOriginalFormat {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Bitrate \(Int(64 + quality * 192))kbps")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(TossyColor.textSecondary)
                        Slider(value: $quality, in: 0...1)
                            .frame(width: 120)
                    }
                }

                Spacer()

                DestinationButton(destinationFolder: effectiveDestinationFolder, action: chooseDestinationFolder)
            }

            DisclosureGroup("Advanced Options", isExpanded: $showAdvanced) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 16) {
                        Toggle("Keep original format (recompress in place)", isOn: $keepOriginalFormat)
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

        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                defer { group.leave() }
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
                }
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

        let maxConcurrency = max(1, AppSettings.shared.maxConcurrentJobs)

        await withTaskGroup(of: Void.self) { group in
            var activeCount = 0
            for job in pendingJobs {
                if activeCount >= maxConcurrency {
                    await group.next()
                    activeCount -= 1
                }
                activeCount += 1
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

        var effectiveFormat = job.overrideAudioFormat ?? selectedFormat
        var formatNote: String?
        if keepOriginalFormat {
            if let matched = AudioFormat.matching(sourceURL: job.sourceURL), matched.isAvailable {
                effectiveFormat = matched
            } else {
                formatNote = "Couldn't match the original format  -  used \(effectiveFormat.displayName) instead."
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
                quality: job.overrideQuality ?? quality,
                destinationFolder: effectiveDestinationFolder,
                targetSizeBytes: targetSizeBytes,
                customBaseName: customBaseName,
                preserveMetadata: preserveMetadata
            ) { progress in
                Task { @MainActor in job.updateProgress(progress) }
            }
            let note = [formatNote, result.note].compactMap { $0 }.joined(separator: " ")
            let finalURL = result.outputURL
            await MainActor.run { job.status = .done(outputURL: finalURL, note: note.isEmpty ? nil : note) }
            handlePostConversion(sourceURL: job.sourceURL, outputURL: finalURL)
        } catch {
            await MainActor.run { job.status = .failed(error.localizedDescription) }
        }
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
