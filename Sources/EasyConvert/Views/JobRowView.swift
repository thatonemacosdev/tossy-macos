import SwiftUI
import AppKit

struct JobRowView: View {
    let job: ConversionJob
    var onRetry: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 12) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: job.sourceURL.path))
                .resizable()
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(job.displayName)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .truncationMode(.middle)
                statusLabel
            }

            Spacer()

            if case .done(let outputURL, _) = job.status {
                HStack(spacing: 8) {
                    Image(systemName: "line.3.horizontal")
                        .foregroundStyle(.secondary)
                        .help("Drag output file")
                    Button {
                        NSWorkspace.shared.activateFileViewerSelecting([outputURL])
                    } label: {
                        Image(systemName: "folder")
                    }
                    .buttonStyle(.borderless)
                    .help("Reveal in Finder")
                }
                .draggable(outputURL)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var statusLabel: some View {
        switch job.status {
        case .pending:
            Label("Waiting", systemImage: "clock")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .converting(let progress, let etaText):
            HStack(spacing: 4) {
                if let progress {
                    ProgressView(value: progress)
                        .frame(width: 80)
                    Text("\(Int(progress * 100))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let etaText {
                        Text("· \(etaText)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ProgressView()
                        .controlSize(.small)
                    Text("Converting…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        case .done(_, let note):
            HStack(spacing: 4) {
                Label("Done", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                if let note {
                    Text("· \(note)")
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .font(.caption)
        case .failed(let message):
            HStack(spacing: 8) {
                Label(message, systemImage: "xmark.octagon.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(1)
                if let onRetry {
                    Button(action: onRetry) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.borderless)
                    .help("Retry conversion")
                }
            }
        }
    }
}
