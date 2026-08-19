import SwiftUI
import AppKit

struct BenchmarkShareCardView: View {
    let score: Int
    let chipName: String
    let coreCount: Int
    let results: [BenchmarkResult]
    @Environment(\.dismiss) private var dismiss

    @State private var hasCopied = false

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("TossyMark Score Card")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.white)
                Spacer()
                Button("Done") { dismiss() }
                    .controlSize(.small)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)

            // The Renderable Card
            cardView
                .frame(width: 520)
                .padding(.horizontal, 20)

            // Actions
            HStack(spacing: 12) {
                Button {
                    copyCardToPasteboard()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: hasCopied ? "checkmark" : "doc.on.doc")
                        Text(hasCopied ? "Copied PNG!" : "Copy Image to Clipboard")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.white)
                .foregroundStyle(.black)
                .controlSize(.regular)

                Button {
                    saveCardImage()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.down")
                        Text("Save PNG…")
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
            }
            .padding(.bottom, 20)
        }
        .background(TossyColor.pitchBlack)
        .preferredColorScheme(AppSettings.shared.appTheme == .light ? .light : .dark)
    }

    private var cardView: some View {
        VStack(spacing: 18) {
            // Card Top Bar
            HStack(alignment: .center) {
                HStack(spacing: 8) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 28, height: 28)
                        .clipShape(RoundedRectangle(cornerRadius: 6))

                    VStack(alignment: .leading, spacing: 1) {
                        Text("TossyMark Benchmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.white)
                        Text("v1.6.0 Suite · Silicon Reference")
                            .font(.system(size: 10))
                            .foregroundStyle(TossyColor.textTertiary)
                    }
                }

                Spacer()

                TossyPill(text: "\(chipName) (\(coreCount) Cores)", isSelected: true)
            }

            Divider().overlay(TossyColor.borderSubtle)

            // Main Score Area
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("OVERALL COMPOSITE SCORE")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(TossyColor.textSecondary)
                        .tracking(1.2)

                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(score)")
                            .font(.system(size: 44, weight: .heavy, design: .rounded))
                            .foregroundStyle(Color.white)

                        Text("pts")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(TossyColor.textSecondary)
                    }
                }

                Spacer()

                // Baseline Tier Comparison
                VStack(alignment: .trailing, spacing: 3) {
                    Text("Baseline Rank")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(TossyColor.textTertiary)

                    Text(tierLabel)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(TossyColor.successGreen)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(TossyColor.successGreen.opacity(0.12))
                        .clipShape(Capsule())
                }
            }

            // Breakdown Bars
            VStack(spacing: 8) {
                breakdownRow(label: "GPU & Image Acceleration", icon: "photo.stack", points: scoreForDomain(.image))
                breakdownRow(label: "Hardware Video Transcoding", icon: "video.fill", points: scoreForDomain(.video))
                breakdownRow(label: "Multi-Core Audio DSP", icon: "waveform", points: scoreForDomain(.audio))
                breakdownRow(label: "Parallel Scaling & Threading", icon: "cpu", points: scoreForDomain(.concurrency))
            }

            Divider().overlay(TossyColor.borderSubtle)

            // Card Footer
            HStack {
                Text("Tested locally on macOS 14+ via Tossy")
                    .font(.system(size: 10))
                    .foregroundStyle(TossyColor.textTertiary)

                Spacer()

                Text("thatonemacosdev.github.io/tossy-macos")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(TossyColor.textSecondary)
            }
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(TossyColor.surfaceBase)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(TossyColor.borderMedium, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.6), radius: 20, y: 10)
    }

    private var tierLabel: String {
        if score >= 60_000 { return "M4 Max / Ultra Class" }
        if score >= 40_000 { return "M4 Pro Workstation" }
        if score >= 28_000 { return "M4 Air Standard" }
        if score >= 16_000 { return "M2 / M3 Class" }
        return "M1 / Intel Legacy"
    }

    private func scoreForDomain(_ domain: BenchmarkDomain) -> Int {
        let items = results.filter { $0.domain == domain }
        guard !items.isEmpty else { return max(1000, score / 4) }
        let total = items.compactMap(\.points).reduce(0, +)
        return total / max(1, items.count)
    }

    @ViewBuilder
    private func breakdownRow(label: String, icon: String, points: Int) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(TossyColor.textSecondary)
                .frame(width: 16)

            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.white)

            Spacer()

            Text("\(points) pts")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(TossyColor.textSecondary)
        }
    }

    // MARK: - Export Logic

    @MainActor
    private func renderCardImage() -> NSImage? {
        let renderer = ImageRenderer(content: cardView.frame(width: 520))
        renderer.scale = 2.0 // High DPI Retina
        return renderer.nsImage
    }

    @MainActor
    private func copyCardToPasteboard() {
        guard let image = renderCardImage() else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([image])
        withAnimation { hasCopied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            hasCopied = false
        }
    }

    @MainActor
    private func saveCardImage() {
        guard let image = renderCardImage() else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "TossyMark-\(score)pts-\(chipName.replacingOccurrences(of: " ", with: "-")).png"
        panel.allowedContentTypes = [.png]
        panel.begin { response in
            if response == .OK, let url = panel.url {
                if let tiff = image.tiffRepresentation,
                   let rep = NSBitmapImageRep(data: tiff),
                   let png = rep.representation(using: .png, properties: [:]) {
                    try? png.write(to: url)
                }
            }
        }
    }
}
