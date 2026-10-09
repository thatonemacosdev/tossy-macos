import SwiftUI

struct BenchmarkGaugeView: View {
    let progress: Double
    let activeTestName: String
    let chipModel: String

    @State private var isPulsing = false

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                // Outer ring track
                Circle()
                    .stroke(TossyColor.surfaceElevated, lineWidth: 10)
                    .frame(width: 140, height: 140)

                // Animated progress arc
                Circle()
                    .trim(from: 0.0, to: max(0.02, progress))
                    .stroke(
                        TossyColor.accentProminentBg,
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 140, height: 140)
                    .animation(.easeInOut(duration: 0.2), value: progress)

                // Inner status readout
                VStack(spacing: 4) {
                    Image(systemName: "speedometer")
                        .font(.system(size: 28, weight: .light))
                        .foregroundStyle(TossyColor.textPrimary)
                        .scaleEffect(isPulsing ? 1.08 : 0.95)
                        .animation(
                            .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                            value: isPulsing
                        )

                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(TossyColor.textPrimary)
                }
            }
            .onAppear {
                isPulsing = true
            }

            VStack(spacing: 6) {
                Text(activeTestName.isEmpty ? "Benchmarking system throughput..." : activeTestName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(TossyColor.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(maxWidth: 420)

                Text(chipModel)
                    .font(.caption)
                    .foregroundStyle(TossyColor.textSecondary)
            }
        }
        .padding(24)
    }
}
