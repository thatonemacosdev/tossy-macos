import SwiftUI
import AppKit

struct BenchmarkView: View {
    @State private var results: [BenchmarkResult] = []
    @State private var isRunning = false
    @State private var currentProgress: Double = 0.0
    @State private var statusText = "Ready to test 32 conversion workloads across Metal GPU, video transcode, audio DSP, and multi-core scaling."
    @State private var activeDomain: BenchmarkDomain = .all
    @State private var runHistory: [BenchmarkRunReport] = []
    @State private var selectedHistoryRun: BenchmarkRunReport?
    @State private var copiedToastText: String? = nil
    @State private var showingShareCardSheet = false

    private let service = BenchmarkService()
    private let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("TossyBenchmark", isDirectory: true)

    private var chipName: String { BenchmarkService.getChipDescription() }
    private var coreCount: Int { ProcessInfo.processInfo.activeProcessorCount }
    private var thermalState: String { BenchmarkService.getThermalStateDescription() }

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider().overlay(TossyColor.borderSubtle)

            if isRunning {
                runningView
            } else if results.isEmpty && runHistory.isEmpty {
                emptyStateView
            } else {
                contentDashboardView
            }

            Divider().overlay(TossyColor.borderSubtle)

            bottomActionBar
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(TossyColor.pitchBlack)
        .onAppear {
            loadRunHistory()
        }
        .sheet(isPresented: $showingShareCardSheet) {
            if let score = overallScore {
                BenchmarkShareCardView(
                    score: score,
                    chipName: chipName,
                    coreCount: coreCount,
                    results: results
                )
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text("TossyMark System Benchmark")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.white)

                    TossyPill(text: "v1.7.0 Suite", isSubtle: true)
                }

                Text("Standardized compute, GPU acceleration, and transcode benchmark calibrated to Apple Silicon reference standards.")
                    .font(.caption)
                    .foregroundStyle(TossyColor.textSecondary)
            }

            Spacer()

            HStack(spacing: 8) {
                TossyPill(text: "\(chipName) (\(coreCount) Cores)", isSubtle: true)
                TossyPill(text: thermalState, isSubtle: true)
            }
        }
        .padding(14)
        .background(TossyColor.pitchBlack)
    }

    // MARK: - Running View

    private var runningView: some View {
        VStack(spacing: 16) {
            Spacer()
            BenchmarkGaugeView(
                progress: currentProgress,
                activeTestName: statusText,
                chipModel: "\(chipName) - \(coreCount) Cores"
            )
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(TossyColor.pitchBlack)
    }

    // MARK: - Empty State View

    private var emptyStateView: some View {
        VStack(spacing: 18) {
            Spacer()

            ZStack {
                Circle()
                    .fill(TossyColor.surfaceElevated)
                    .frame(width: 84, height: 84)

                Image(systemName: "speedometer")
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(Color.white)
            }

            VStack(spacing: 6) {
                Text("Comprehensive Benchmark Suite")
                    .font(.headline)
                    .foregroundStyle(Color.white)

                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(TossyColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 480)
            }

            Button {
                Task { await runAll() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "play.fill")
                    Text("Run 32-Workload Benchmark")
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.white)
            .foregroundStyle(.black)
            .controlSize(.large)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }

    // MARK: - Main Content Dashboard

    private var contentDashboardView: some View {
        ScrollView {
            VStack(spacing: 14) {
                // Top Score Card
                if let score = overallScore {
                    scoreOverviewCard(score: score)
                    BenchmarkHardwareScaleView(currentScore: score)
                }

                // Domain Filter & History Selector
                domainFilterBar

                // Test Table
                resultsTableView
            }
            .padding(14)
        }
    }

    // MARK: - Score Overview Card

    private func scoreOverviewCard(score: Int) -> some View {
        VStack(spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("OVERALL TOSSYMARK")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(TossyColor.textSecondary)

                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(score)")
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.white)

                        Text("pts")
                            .font(.title3.weight(.medium))
                            .foregroundStyle(TossyColor.textTertiary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 6) {
                    let stability = BenchmarkReferences.overallStabilityIndex(for: displayedResults)
                    HStack(spacing: 6) {
                        Image(systemName: "waveform.path.ecg")
                            .font(.caption)
                            .foregroundStyle(TossyColor.successGreen)
                        Text(String(format: "Stability: %.1f%%", stability))
                            .font(.caption.weight(.medium))
                            .foregroundStyle(TossyColor.textSecondary)
                    }

                    Text("Calibrated baseline standard = 10,000 pts (Apple M2)")
                        .font(.caption2)
                        .foregroundStyle(TossyColor.textTertiary)
                }
            }

            Divider().overlay(TossyColor.borderSubtle)

            // Sub-scores
            HStack(spacing: 10) {
                subScoreChip(title: "ImageMark", value: BenchmarkReferences.domainScore(for: results, in: .image), icon: "photo.stack")
                subScoreChip(title: "VideoMark", value: BenchmarkReferences.domainScore(for: results, in: .video), icon: "film")
                subScoreChip(title: "AudioMark", value: BenchmarkReferences.domainScore(for: results, in: .audio), icon: "waveform")
                subScoreChip(title: "ConcurrencyMark", value: BenchmarkReferences.domainScore(for: results, in: .concurrency), icon: "cpu")
            }
        }
        .padding(16)
        .tossyCard(cornerRadius: 14, isHighlighted: true)
    }

    private func subScoreChip(title: String, value: Int, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(TossyColor.textSecondary)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(TossyColor.textTertiary)

                Text(value > 0 ? "\(value)" : " - ")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(TossyColor.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Domain Filter Bar

    private var domainFilterBar: some View {
        HStack(spacing: 6) {
            ForEach(BenchmarkDomain.allCases) { domain in
                let count = results.filter { domain == .all || $0.domain == domain }.count
                Button {
                    activeDomain = domain
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: domain.iconName)
                            .font(.system(size: 11))
                        Text(domain.rawValue)
                            .font(.system(size: 12, weight: .medium))
                        if count > 0 {
                            Text("(\(count))")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(activeDomain == domain ? Color.black.opacity(0.8) : TossyColor.textTertiary)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(activeDomain == domain ? Color.white : TossyColor.surfaceElevated)
                    .foregroundStyle(activeDomain == domain ? Color.black : Color.white)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            Spacer()

            if let copiedToastText {
                Text(copiedToastText)
                    .font(.caption)
                    .foregroundStyle(TossyColor.successGreen)
                    .transition(.opacity)
            }
        }
    }

    // MARK: - Results Table

    private var displayedResults: [BenchmarkResult] {
        if activeDomain == .all {
            return results
        }
        return results.filter { $0.domain == activeDomain }
    }

    private var resultsTableView: some View {
        VStack(spacing: 6) {
            ForEach(displayedResults) { item in
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.label)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.white)

                        if !item.descriptionText.isEmpty {
                            Text(item.descriptionText)
                                .font(.caption2)
                                .foregroundStyle(TossyColor.textSecondary)
                        }
                    }

                    Spacer()

                    // Throughput metric
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(item.detail)
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundStyle(Color.white)

                        Text(String(format: "%.2fs median", item.duration))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(TossyColor.textTertiary)
                    }
                    .frame(width: 140, alignment: .trailing)

                    // Point Score Bar
                    if let pts = item.points {
                        VStack(alignment: .trailing, spacing: 2) {
                            HStack(spacing: 4) {
                                Text("\(pts)")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color.white)
                                Text("pts")
                                    .font(.system(size: 10))
                                    .foregroundStyle(TossyColor.textTertiary)
                            }

                            // Visual mini-bar relative to 32k M4 Air baseline
                            let fraction = min(1.0, max(0.05, Double(pts) / 60_000.0))
                            GeometryReader { g in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(TossyColor.surfaceElevated)
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color.white)
                                        .frame(width: g.size.width * fraction)
                                }
                            }
                            .frame(width: 70, height: 4)
                        }
                        .frame(width: 85, alignment: .trailing)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(TossyColor.surfaceDeep)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    // MARK: - Bottom Action Bar

    private var bottomActionBar: some View {
        HStack {
            Text(statusText)
                .font(.caption)
                .foregroundStyle(TossyColor.textSecondary)
                .lineLimit(1)

            Spacer()

            if !results.isEmpty && !isRunning {
                Button {
                    copyBadgeToClipboard()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "doc.on.doc")
                        Text("Copy Badge")
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(TossyColor.surfaceElevated)
                .foregroundStyle(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .font(.caption)

                Button {
                    showingShareCardSheet = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "photo")
                        Text("Share Card")
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(TossyColor.surfaceElevated)
                .foregroundStyle(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .font(.caption)

                Button {
                    exportJSONReport()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "square.and.arrow.up")
                        Text("Export JSON")
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(TossyColor.surfaceElevated)
                .foregroundStyle(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .font(.caption)
            }

            Button {
                Task { await runAll() }
            } label: {
                if isRunning {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.small)
                        Text("Benchmarking…")
                    }
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: results.isEmpty ? "play.fill" : "arrow.clockwise")
                        Text(results.isEmpty ? "Run Benchmark Suite" : "Re-run Benchmark")
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.white)
            .foregroundStyle(.black)
            .controlSize(.regular)
            .disabled(isRunning)
        }
        .padding(12)
        .background(TossyColor.surfaceDeep)
    }

    // MARK: - Scoring Calculation

    private var overallScore: Int? {
        guard !results.isEmpty else { return nil }
        return BenchmarkReferences.compositeScore(for: results)
    }

    // MARK: - Execution

    private func runAll() async {
        isRunning = true
        results = []
        currentProgress = 0.0
        defer { isRunning = false }

        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // 1. Warmup
        await service.runWarmup(tempDir: tempDir) { status in
            Task { @MainActor in
                statusText = status
                currentProgress = 0.05
            }
        }

        // 2. Images (12 tests)
        let imageResults = await service.runImageBenchmark(tempDir: tempDir) { status in
            Task { @MainActor in
                statusText = status
                currentProgress = min(0.40, currentProgress + 0.03)
            }
        }
        results.append(contentsOf: imageResults)
        currentProgress = 0.40

        // 3. Video (10 tests)
        let videoResults = await service.runVideoBenchmark(tempDir: tempDir) { status in
            Task { @MainActor in
                statusText = status
                currentProgress = min(0.75, currentProgress + 0.03)
            }
        }
        results.append(contentsOf: videoResults)
        currentProgress = 0.75

        // 4. Audio (6 tests)
        let audioResults = await service.runAudioBenchmark(tempDir: tempDir) { status in
            Task { @MainActor in
                statusText = status
                currentProgress = min(0.90, currentProgress + 0.02)
            }
        }
        results.append(contentsOf: audioResults)
        currentProgress = 0.90

        // 5. Concurrency (4 tests)
        let concurrencyResults = await service.runConcurrencyBenchmark(tempDir: tempDir) { status in
            Task { @MainActor in
                statusText = status
                currentProgress = min(0.98, currentProgress + 0.02)
            }
        }
        results.append(contentsOf: concurrencyResults)
        currentProgress = 1.0

        let finalScore = BenchmarkReferences.compositeScore(for: results)
        statusText = "Benchmark complete: \(results.count) tests finished with TossyMark score \(finalScore)."

        saveRunToHistory(score: finalScore)
    }

    // MARK: - History & Export

    private func saveRunToHistory(score: Int) {
        let report = BenchmarkRunReport(
            timestamp: Date(),
            deviceModel: chipName,
            chipDescription: chipName,
            coreCount: coreCount,
            thermalState: thermalState,
            overallTossyMark: score,
            imageMark: BenchmarkReferences.domainScore(for: results, in: .image),
            videoMark: BenchmarkReferences.domainScore(for: results, in: .video),
            audioMark: BenchmarkReferences.domainScore(for: results, in: .audio),
            concurrencyMark: BenchmarkReferences.domainScore(for: results, in: .concurrency),
            stabilityIndex: BenchmarkReferences.overallStabilityIndex(for: results),
            results: results
        )

        var history = runHistory
        history.insert(report, at: 0)
        if history.count > 5 {
            history = Array(history.prefix(5))
        }
        runHistory = history

        if let encoded = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(encoded, forKey: "tossy_benchmark_history")
        }
    }

    private func loadRunHistory() {
        guard let data = UserDefaults.standard.data(forKey: "tossy_benchmark_history"),
              let decoded = try? JSONDecoder().decode([BenchmarkRunReport].self, from: data) else { return }
        self.runHistory = decoded
        if let latest = decoded.first, results.isEmpty {
            self.results = latest.results
        }
    }

    private func copyBadgeToClipboard() {
        guard let score = overallScore else { return }
        let badge = """
        **TossyMark Benchmark**: `\(score) pts`
        - Hardware: \(chipName) (\(coreCount) Cores)
        - ImageMark: \(BenchmarkReferences.domainScore(for: results, in: .image)) | VideoMark: \(BenchmarkReferences.domainScore(for: results, in: .video)) | AudioMark: \(BenchmarkReferences.domainScore(for: results, in: .audio)) | ConcurrencyMark: \(BenchmarkReferences.domainScore(for: results, in: .concurrency))
        - Reference Standard: Apple M2 Mac = 10,000 pts
        """
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(badge, forType: .string)

        withAnimation {
            copiedToastText = "Copied badge to clipboard!"
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation {
                copiedToastText = nil
            }
        }
    }

    private func exportJSONReport() {
        guard let score = overallScore else { return }
        let report = BenchmarkRunReport(
            timestamp: Date(),
            deviceModel: chipName,
            chipDescription: chipName,
            coreCount: coreCount,
            thermalState: thermalState,
            overallTossyMark: score,
            imageMark: BenchmarkReferences.domainScore(for: results, in: .image),
            videoMark: BenchmarkReferences.domainScore(for: results, in: .video),
            audioMark: BenchmarkReferences.domainScore(for: results, in: .audio),
            concurrencyMark: BenchmarkReferences.domainScore(for: results, in: .concurrency),
            stabilityIndex: BenchmarkReferences.overallStabilityIndex(for: results),
            results: results
        )

        if let data = try? JSONEncoder().encode(report),
           let jsonString = String(data: data, encoding: .utf8) {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(jsonString, forType: .string)
            withAnimation {
                copiedToastText = "Copied JSON report to clipboard!"
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation {
                    copiedToastText = nil
                }
            }
        }
    }
}
