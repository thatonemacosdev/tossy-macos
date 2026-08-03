import SwiftUI
import AppKit

struct JobRowView: View {
    let job: ConversionJob

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
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([outputURL])
                } label: {
                    Image(systemName: "folder")
                }
                .buttonStyle(.borderless)
                .help("Reveal in Finder")
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
        case .converting(let progress):
            HStack(spacing: 4) {
                if let progress {
                    ProgressView(value: progress)
                        .frame(width: 80)
                    Text("\(Int(progress * 100))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
            Label(message, systemImage: "xmark.octagon.fill")
                .font(.caption)
                .foregroundStyle(.red)
                .lineLimit(1)
        }
    }
}
