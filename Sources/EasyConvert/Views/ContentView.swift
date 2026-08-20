import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct ContentView: View {
    @State private var jobs: [ConversionJob] = []
    @State private var selectedFormat: ImageFormat = .png
    @State private var quality: Double = 0.85
    @State private var destinationFolder: URL?
    @State private var isTargeted = false
    @State private var isConverting = false
    @State private var isShowingImporter = false
    @State private var isShowingInspector = false
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

            Divider().overlay(TossyColor.borderSubtle)

            if jobs.isEmpty {
                DropZoneView(
                    isTargeted: isTargeted,
                    icon: "photo.badge.arrow.down",
                    title: "Toss images here to convert",
                    subtitle: "PNG, JPEG, WebP, HEIC, AVIF, TIFF, BMP, GIF, JPEG XL, and RAW camera files",
                    formatTags: ["PNG", "JPEG", "WebP", "HEIC", "AVIF", "JXL", "RAW"]
                ) { isShowingImporter = true }
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(jobs) { job in
                            JobRowView(
                                job: job,
                                categoryType: .image,
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
        .onDrop(of: [.fileURL, .image, .png, .jpeg, .tiff, .data, .item], isTargeted: $isTargeted) { providers in
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
            HStack(spacing: 12) {
                Picker("Convert to", selection: $selectedFormat) {
                    ForEach(ImageFormat.allCases) { format in
                        Text(format.isAvailable ? format.displayName : "\(format.displayName) (unavailable)")
                            .tag(format)
                    }
                }
                .frame(width: 230)
                .disabled(keepOriginalFormat)

                // Format Inspector Knob Button
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
                .help("Configure deep CLI encoding parameters for \(selectedFormat.displayName)")
                .popover(isPresented: $isShowingInspector) {
                    FormatInspectorView(category: .image(format: selectedFormat))
                }

                if selectedFormat.supportsQuality && !keepOriginalFormat {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Quality \(Int(quality * 100))%")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(TossyColor.textSecondary)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                        Slider(value: $quality, in: 0.1...1.0)
                            .frame(width: 120)
                    }
                    .fixedSize(horizontal: true, vertical: false)
                }

                Spacer()

                DestinationButton(destinationFolder: effectiveDestinationFolder, action: chooseDestinationFolder)
            }

            DisclosureGroup("Advanced Options", isExpanded: $showAdvanced) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 16) {
                        Toggle("Keep original format (recompress in place)", isOn: $keepOriginalFormat)
                            .toggleStyle(.checkbox)

                        Toggle("Preserve EXIF/GPS/TIFF metadata", isOn: $preserveMetadata)
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
                    Text("Processing via Metal & ImageIO (Threads: \(AppSettings.shared.maxConcurrentJobs))")
                        .font(.caption)
                        .foregroundStyle(TossyColor.textSecondary)
                }
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "cpu")
                        .font(.system(size: 10))
                        .foregroundStyle(TossyColor.textTertiary)
                    Text("Engine: Metal / ImageIO / libwebp")
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
                        self.extractImageData(from: provider, lock: lock) { url in
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
                self.extractImageData(from: provider, lock: lock) { url in
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

    private func extractImageData(from provider: NSItemProvider, lock: NSLock, completion: @escaping (URL?) -> Void) {
        if provider.hasItemConformingToTypeIdentifier(UTType.png.identifier) {
            provider.loadDataRepresentation(forTypeIdentifier: UTType.png.identifier) { data, _ in
                if let data, let url = self.writeTempScreenshot(data: data, ext: "png") {
                    completion(url)
                    return
                }
                self.extractImageObject(from: provider, completion: completion)
            }
        } else if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
            provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                if let data, let url = self.writeTempScreenshot(data: data, ext: "png") {
                    completion(url)
                    return
                }
                self.extractImageObject(from: provider, completion: completion)
            }
        } else if provider.hasItemConformingToTypeIdentifier(UTType.data.identifier) {
            provider.loadDataRepresentation(forTypeIdentifier: UTType.data.identifier) { data, _ in
                if let data, let url = self.writeTempScreenshot(data: data, ext: "png") {
                    completion(url)
                    return
                }
                self.extractImageObject(from: provider, completion: completion)
            }
        } else {
            self.extractImageObject(from: provider, completion: completion)
        }
    }

    private func extractImageObject(from provider: NSItemProvider, completion: @escaping (URL?) -> Void) {
        if provider.canLoadObject(ofClass: NSImage.self) {
            provider.loadObject(ofClass: NSImage.self) { image, _ in
                guard let nsImage = image as? NSImage,
                      let tiffData = nsImage.tiffRepresentation,
                      let bitmap = NSBitmapImageRep(data: tiffData),
                      let pngData = bitmap.representation(using: .png, properties: [:]) else {
                    completion(nil)
                    return
                }
                let url = self.writeTempScreenshot(data: pngData, ext: "png")
                completion(url)
            }
        } else {
            completion(nil)
        }
    }

    private func writeTempScreenshot(data: Data, ext: String) -> URL? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        let timestamp = formatter.string(from: Date())
        let filename = "Screenshot \(timestamp) \(UUID().uuidString.prefix(4)).\(ext)"
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

        var effectiveFormat = job.overrideImageFormat ?? selectedFormat
        var formatNote: String?
        if keepOriginalFormat {
            if let matched = ImageFormat.matching(sourceURL: job.sourceURL), matched.isAvailable {
                effectiveFormat = matched
            } else {
                formatNote = "Couldn't match the original format  -  used \(effectiveFormat.displayName) instead."
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
                var firstOutput: URL?
                var succeededWidths: [Int] = []
                var lastFailure: String?
                for width in exportWidths {
                    do {
                        let result = try await converter.convert(
                            sourceURL: job.sourceURL,
                            to: effectiveFormat,
                            quality: job.overrideQuality ?? quality,
                            destinationFolder: effectiveDestinationFolder,
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
                let finalURL = firstOutput ?? job.sourceURL
                await MainActor.run { job.status = .done(outputURL: finalURL, note: note) }
                handlePostConversion(sourceURL: job.sourceURL, outputURL: finalURL)
            } else {
                let result = try await converter.convert(
                    sourceURL: job.sourceURL,
                    to: effectiveFormat,
                    quality: job.overrideQuality ?? quality,
                    destinationFolder: effectiveDestinationFolder,
                    targetSizeBytes: targetSizeBytes,
                    targetWidth: exportWidths.first,
                    customBaseName: customBaseName,
                    preserveMetadata: preserveMetadata
                )
                let note = [formatNote, result.note].compactMap { $0 }.joined(separator: " ")
                let finalURL = result.outputURLs[0]
                await MainActor.run { job.status = .done(outputURL: finalURL, note: note.isEmpty ? nil : note) }
                handlePostConversion(sourceURL: job.sourceURL, outputURL: finalURL)
            }
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
