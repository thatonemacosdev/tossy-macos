import SwiftUI

struct BenchmarkHardwareScaleView: View {
    let currentScore: Int
    let hardwareTiers = BenchmarkReferences.hardwareTiers

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Hardware Baseline Comparison")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.white)

                Spacer()

                Text("Reference Standard: M2 Mac (10,000 pts)")
                    .font(.caption2)
                    .foregroundStyle(TossyColor.textTertiary)
            }

            GeometryReader { geo in
                let width = geo.size.width
                let maxPoints = 40_000.0

                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 6)
                        .fill(TossyColor.surfaceElevated)
                        .frame(height: 12)

                    // Reference threshold marker at 10,000 pts (1/3 of bar)
                    let refPos = width * (10_000.0 / maxPoints)
                    Rectangle()
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 2, height: 20)
                        .offset(x: refPos - 1)

                    // Current score fill bar
                    let fillWidth = max(8.0, min(width, width * (Double(currentScore) / maxPoints)))
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.7), Color.white],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: fillWidth, height: 12)

                    // Glowing needle indicator
                    Circle()
                        .fill(Color.white)
                        .frame(width: 16, height: 16)
                        .shadow(color: Color.white.opacity(0.8), radius: 6, x: 0, y: 0)
                        .offset(x: fillWidth - 8)
                }
            }
            .frame(height: 20)

            // Tier Labels below scale
            HStack(alignment: .top) {
                ForEach(hardwareTiers) { tier in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(tier.name)
                            .font(.system(size: 10, weight: tier.isReference ? .bold : .medium))
                            .foregroundStyle(tier.isReference ? Color.white : TossyColor.textSecondary)

                        Text("\(tier.tossyMark)")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(TossyColor.textTertiary)
                    }
                    if tier.id != hardwareTiers.last?.id {
                        Spacer()
                    }
                }
            }
        }
        .padding(14)
        .tossyCard(cornerRadius: 12)
    }
}
