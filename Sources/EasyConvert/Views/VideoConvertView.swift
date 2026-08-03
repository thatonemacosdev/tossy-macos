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
    @State private var showAdvanced = false

    private var targetSizeBytes: Int64? { ByteSize.parse(targetSizeText) }
    private var targetWidth: Int? { Int(resizeWidthText.trimmingCharacters(in: .whitespaces)) }

    private let converter = VideoConverter()

    var body: some View {
        VStack(spacing: 0) {
            controlBar

            Divider()

            if jobs.isEmpty {
                DropZoneView(
                    isTargeted: isTargeted,
                    icon: "video.badge.arrow.down",
                    title: "Drag videos here to convert",
                    subtitle: "MP4, MOV, M4V, and more — encoded in hardware via VideoToolbox"
                ) { isShowingImporter = true }
            } else {
                List(jobs) { job in
                    JobRowView(job: job)
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

                Button("Choose Destination…") { chooseDestinationFolder() }
                    .buttonStyle(.bordered)
            }

            DisclosureGroup("Advanced", isExpanded: $showAdvanced) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 16) {
                        Toggle("Keep original container (just recompress)", isOn: $keepOriginalContainer)
                            .toggleStyle(.checkbox)

                        TargetSizeField(text: $targetSizeText)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Resize width")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            TextField("e.g. 1280", text: $resizeWidthText)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 90)
                        }

                        MaxFileSizeMenu()

                        Spacer()
                    }

                    if targetSizeBytes != nil || targetWidth != nil {
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
            Text(destinationSummary)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            if !jobs.isEmpty {
                Button("Add Files…") { isShowingImporter = true }
                Button("Clear") { jobs.removeAll() }
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

    private var destinationSummary: String {
        if let destinationFolder {
            return "Saving to \(destinationFolder.lastPathComponent)"
        }
        return "Saving alongside each original"
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
    }

    private func convert(job: ConversionJob) async {
        if let sizeWarning = FeasibilityChecker.checkFileSize(job.sourceURL) {
            await MainActor.run { job.status = .failed(sizeWarning) }
            return
        }

        if keepOriginalContainer {
            guard let targetSizeBytes else {
                await MainActor.run { job.status = .failed("\"Keep original container\" needs a target size to compress toward — set one above.") }
                return
            }
            await MainActor.run { job.status = .converting(progress: 0) }
            do {
                let result = try await converter.compressKeepingContainer(
                    sourceURL: job.sourceURL,
                    destinationFolder: destinationFolder,
                    targetSizeBytes: targetSizeBytes,
                    targetWidth: targetWidth
                ) { progress in
                    Task { @MainActor in job.status = .converting(progress: progress) }
                }
                await MainActor.run { job.status = .done(outputURL: result.outputURL, note: result.note) }
            } catch {
                await MainActor.run { job.status = .failed(error.localizedDescription) }
            }
            return
        }

        guard selectedFormat.isAvailable else {
            await MainActor.run { job.status = .failed(selectedFormat.unavailabilityReason ?? "Unavailable format.") }
            return
        }
        await MainActor.run { job.status = .converting(progress: 0) }
        do {
            let result = try await converter.convert(
                sourceURL: job.sourceURL,
                to: selectedFormat,
                destinationFolder: destinationFolder,
                targetSizeBytes: targetSizeBytes,
                targetWidth: targetWidth
            ) { progress in
                Task { @MainActor in job.status = .converting(progress: progress) }
            }
            await MainActor.run { job.status = .done(outputURL: result.outputURL, note: result.note) }
        } catch {
            await MainActor.run { job.status = .failed(error.localizedDescription) }
        }
    }
}
