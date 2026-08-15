import SwiftUI

struct BenchmarkView: View {
    @State private var results: [BenchmarkResult] = []
    @State private var isRunning = false
    @State private var statusText = "Runs synthetic, GPU-generated test images, a 1080p test clip, and a test tone  -  no sample files needed."

    private let service = BenchmarkService()
    private let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("TossyBenchmark", isDirectory: true)

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider().overlay(TossyColor.borderSubtle)

            if results.isEmpty {
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(TossyColor.surfaceElevated)
                            .frame(width: 80, height: 80)
                        Image(systemName: "speedometer")
                            .font(.system(size: 40, weight: .light))
                            .foregroundStyle(Color.white)
                    }

                    Text(statusText)
                        .font(.system(size: 13))
                        .foregroundStyle(TossyColor.textSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 400)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                if let overallScore {
                    overallScoreCard(overallScore)
                }
                Table(scoredResults) {
                    TableColumn("Category", value: \.category)
                    TableColumn("Test", value: \.label)
                    TableColumn("Time") { result in
                        Text(String(format: "%.2fs", result.duration))
                            .font(.system(size: 12, design: .monospaced))
                    }
                    TableColumn("Throughput", value: \.detail)
                    TableColumn("Score") { result in
                        if let score = result.score {
                            scoreBar(score)
                        } else {
                            Text(" - ").foregroundStyle(TossyColor.textTertiary)
                        }
                    }
                }
            }

            Divider().overlay(TossyColor.borderSubtle)

            HStack {
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(TossyColor.textSecondary)
                    .lineLimit(1)

                Spacer()

                Button {
                    Task { await runAll() }
                } label: {
                    if isRunning {
                        HStack(spacing: 6) {
                            ProgressView().controlSize(.small)
                            Text("Running Benchmarks…")
                        }
                    } else {
                        HStack(spacing: 6) {
                            Image(systemName: "play.fill")
                            Text("Run Benchmark Suite")
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
        .frame(minWidth: 620, minHeight: 460)
        .background(TossyColor.pitchBlack)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Performance Benchmark")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white)
                
                Spacer()
                
                TossyPill(text: "Apple Silicon & Metal GPU", isSubtle: true)
            }
            Text("Compares the Metal-backed GPU image pipeline against a CPU-only baseline, and times hardware video/audio transcoding. Scores are 0–100, calibrated so a baseline Apple M4 MacBook Air scores 70 on every test.")
                .font(.caption)
                .foregroundStyle(TossyColor.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(TossyColor.pitchBlack)
    }

    // MARK: - Scoring

    private struct ScoredResult: Identifiable {
        let base: BenchmarkResult
        var id: UUID { base.id }
        var category: String { base.category }
        var label: String { base.label }
        var duration: TimeInterval { base.duration }
        var detail: String { base.detail }
        let score: Int?
    }

    private var scoredResults: [ScoredResult] {
        var maxByGroup: [String: Double] = [:]
        for result in results {
            guard let value = result.metricValue else { continue }
            maxByGroup[result.scoreGroup] = max(maxByGroup[result.scoreGroup] ?? 0, value)
        }
        return results.map { result in
            guard let value = result.metricValue else {
                return ScoredResult(base: result, score: nil)
            }
            if let calibratedScore = BenchmarkReferences.score(label: result.label, value: value) {
                return ScoredResult(base: result, score: calibratedScore)
            }
            guard let maxValue = maxByGroup[result.scoreGroup], maxValue > 0 else {
                return ScoredResult(base: result, score: nil)
            }
            let score = min(100, Int((value / maxValue) * 100))
            return ScoredResult(base: result, score: score)
        }
    }

    private var overallScore: Int? {
        let scores = scoredResults.compactMap(\.score)
        guard !scores.isEmpty else { return nil }
        return scores.reduce(0, +) / scores.count
    }

    private func overallScoreCard(_ score: Int) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Overall System Score")
                    .font(.caption)
                    .foregroundStyle(TossyColor.textSecondary)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(score)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(scoreColor(score))
                    Text("/ 100")
                        .font(.title3)
                        .foregroundStyle(TossyColor.textTertiary)
                }
            }
            Spacer()
            Text("Averaged across all conversions tested this run, scored against calibrated baseline performance.")
                .font(.caption)
                .foregroundStyle(TossyColor.textSecondary)
                .frame(maxWidth: 320, alignment: .trailing)
                .multilineTextAlignment(.trailing)
        }
        .padding(14)
        .tossyCard(cornerRadius: 12, isHighlighted: true)
        .padding([.horizontal, .top], 12)
    }

    private func scoreBar(_ score: Int) -> some View {
        HStack(spacing: 6) {
            ProgressView(value: Double(score), total: 100)
                .frame(width: 60)
                .tint(scoreColor(score))
            Text("\(score)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(Color.white)
                .frame(width: 24, alignment: .trailing)
        }
    }

    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 80...: return TossyColor.successGreen
        case 50..<80: return TossyColor.warningAmber
        default: return TossyColor.errorRed
        }
    }

    // MARK: - Running

    private func runAll() async {
        isRunning = true
        results = []
        defer { isRunning = false }

        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let imageResults = await service.runImageBenchmark(
            resolutions: [512, 1024, 2048, 4096],
            formats: [.jpeg, .heic, .png, .avif],
            tempDir: tempDir
        ) { status in
            Task { @MainActor in statusText = status }
        }
        results.append(contentsOf: imageResults)

        let videoResults = await service.runVideoBenchmark(
            formats: [.mp4H264, .mp4Hevc, .movProRes422, .mkv, .webm],
            tempDir: tempDir
        ) { status in
            Task { @MainActor in statusText = status }
        }
        results.append(contentsOf: videoResults)

        let audioResults = await service.runAudioBenchmark(
            formats: [.mp3, .aac, .flac, .opus],
            tempDir: tempDir
        ) { status in
            Task { @MainActor in statusText = status }
        }
        results.append(contentsOf: audioResults)

        statusText = "Done  -  \(results.count) conversions timed."
    }
}
