import SwiftUI
import AppKit

enum JobCategoryType {
    case image, video, audio
}

struct JobRowView: View {
    let job: ConversionJob
    var categoryType: JobCategoryType = .image
    var onRetry: (() -> Void)? = nil
    var onRemove: (() -> Void)? = nil

    @State private var isHovered = false
    @State private var showingOverrideSheet = false
    @State private var showingComparisonSheet = false

    var body: some View {
        HStack(spacing: 12) {
            // Source File Icon
            Image(nsImage: NSWorkspace.shared.icon(forFile: job.sourceURL.path))
                .resizable()
                .frame(width: 32, height: 32)
                .shadow(color: Color.black.opacity(0.4), radius: 3)

            // Name & Status Details
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(job.displayName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.white)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    
                    if !job.sourceFileSizeFormatted.isEmpty {
                        Text("(\(job.sourceFileSizeFormatted))")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(TossyColor.textTertiary)
                    }

                    // Format Override Tag if set
                    if let overrideLabel = currentOverrideLabel {
                        TossyPill(text: overrideLabel, isSelected: true)
                    }
                }

                statusView
            }

            Spacer()

            // Trailing Actions
            trailingActions
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isHovered ? TossyColor.surfaceElevated : TossyColor.surfaceBase)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(isHovered ? TossyColor.borderMedium : TossyColor.borderSubtle, lineWidth: 1)
        )
        .scaleEffect(isHovered ? 1.008 : 1.0)
        .animation(TossyMotion.springSnappy, value: isHovered)
        .onHover { isHovered = $0 }
        .popover(isPresented: $showingOverrideSheet) {
            jobOverridePopover
        }
        .sheet(isPresented: $showingComparisonSheet) {
            if case .done(let outputURL, _) = job.status {
                BeforeAfterComparisonView(sourceURL: job.sourceURL, outputURL: outputURL)
            }
        }
    }

    private var currentOverrideLabel: String? {
        if let fmt = job.overrideImageFormat { return "→ \(fmt.displayName)" }
        if let fmt = job.overrideVideoFormat { return "→ \(fmt.displayName)" }
        if let fmt = job.overrideAudioFormat { return "→ \(fmt.displayName)" }
        return nil
    }

    @ViewBuilder
    private var statusView: some View {
        switch job.status {
        case .pending:
            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .font(.system(size: 10))
                Text("Waiting in queue")
                    .font(.caption)
            }
            .foregroundStyle(TossyColor.textSecondary)

        case .converting(let progress, let etaText):
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    TossyProgressWave(progress: progress)
                        .frame(width: 120)

                    if let progress {
                        Text("\(Int(progress * 100))%")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Color.white)
                    } else {
                        Text("Converting…")
                            .font(.caption)
                            .foregroundStyle(TossyColor.textSecondary)
                    }

                    if let etaText {
                        Text("· \(etaText)")
                            .font(.caption2)
                            .foregroundStyle(TossyColor.textTertiary)
                    }
                }
            }

        case .done(_, let note):
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(TossyColor.successGreen)

                Text("Ready")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.white)

                if let note {
                    Text("· \(note)")
                        .font(.caption)
                        .foregroundStyle(TossyColor.textSecondary)
                        .lineLimit(1)
                }
            }

        case .failed(let message):
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.octagon.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(TossyColor.errorRed)

                Text(message)
                    .font(.caption)
                    .foregroundStyle(TossyColor.errorRed)
                    .lineLimit(1)
            }
        }
    }

    @ViewBuilder
    private var trailingActions: some View {
        switch job.status {
        case .pending:
            HStack(spacing: 6) {
                Button {
                    showingOverrideSheet = true
                } label: {
                    Image(systemName: "slider.horizontal.2")
                        .font(.system(size: 11))
                }
                .buttonStyle(.borderless)
                .foregroundStyle(TossyColor.textSecondary)
                .help("Customize format & settings for this file")

                if let onRemove {
                    Button(action: onRemove) {
                        Image(systemName: "xmark.circle")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(TossyColor.textTertiary)
                    .help("Remove from queue")
                }
            }

        case .converting:
            EmptyView()

        case .done(let outputURL, let note):
            HStack(spacing: 8) {
                Button {
                    showingComparisonSheet = true
                } label: {
                    Image(systemName: "square.split.2x1")
                        .font(.system(size: 11))
                }
                .buttonStyle(.borderless)
                .foregroundStyle(TossyColor.textSecondary)
                .help("Inspect & Compare Quality Before / After")

                TossyDragChip(url: outputURL, note: note)
            }

        case .failed:
            if let onRetry {
                TossyIconButton(icon: "arrow.clockwise", title: "Retry", action: onRetry)
            }
        }
    }

    // MARK: - Job Override Popover

    private var jobOverridePopover: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Customize Job: \(job.displayName)")
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Spacer()
                Button("Done") {
                    showingOverrideSheet = false
                }
                .controlSize(.small)
            }

            Divider().overlay(TossyColor.borderSubtle)

            switch categoryType {
            case .image:
                Picker("Target Format", selection: Binding(
                    get: { job.overrideImageFormat ?? .png },
                    set: { job.overrideImageFormat = $0 }
                )) {
                    ForEach(ImageFormat.allCases) { format in
                        Text(format.displayName).tag(format)
                    }
                }
                .pickerStyle(.menu)

            case .video:
                Picker("Target Format", selection: Binding(
                    get: { job.overrideVideoFormat ?? .mp4H264 },
                    set: { job.overrideVideoFormat = $0 }
                )) {
                    ForEach(VideoFormat.allCases) { format in
                        Text(format.displayName).tag(format)
                    }
                }
                .pickerStyle(.menu)

            case .audio:
                Picker("Target Format", selection: Binding(
                    get: { job.overrideAudioFormat ?? .mp3 },
                    set: { job.overrideAudioFormat = $0 }
                )) {
                    ForEach(AudioFormat.allCases) { format in
                        Text(format.displayName).tag(format)
                    }
                }
                .pickerStyle(.menu)
            }

            HStack {
                Button("Reset to Batch Default") {
                    job.overrideImageFormat = nil
                    job.overrideVideoFormat = nil
                    job.overrideAudioFormat = nil
                    showingOverrideSheet = false
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Spacer()
            }
        }
        .padding(14)
        .frame(width: 320)
        .background(TossyColor.pitchBlack)
        .preferredColorScheme(AppSettings.shared.appTheme == .light ? .light : .dark)
    }
}
