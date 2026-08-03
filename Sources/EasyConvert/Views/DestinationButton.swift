import SwiftUI

/// Shows the chosen destination folder right in the top bar (not just buried in a status
/// line), with a button to change it.
struct DestinationButton: View {
    let destinationFolder: URL?
    let action: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            if let destinationFolder {
                Label(destinationFolder.lastPathComponent, systemImage: "folder.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .help(destinationFolder.path)
            }
            Button(destinationFolder == nil ? "Choose Destination…" : "Change…") { action() }
                .buttonStyle(.bordered)
        }
    }
}
