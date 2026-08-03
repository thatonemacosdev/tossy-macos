import SwiftUI

/// Shared control (used by the Images/Video/Audio tabs) for the max input file size —
/// files larger than this are flagged with a warning instead of silently attempted.
struct MaxFileSizeMenu: View {
    @Bindable private var settings = AppSettings.shared

    var body: some View {
        Menu {
            ForEach(AppSettings.sizePresets, id: \.label) { preset in
                Button {
                    settings.maxFileSizeBytes = preset.bytes
                } label: {
                    if settings.maxFileSizeBytes == preset.bytes {
                        Label(preset.label, systemImage: "checkmark")
                    } else {
                        Text(preset.label)
                    }
                }
            }
        } label: {
            Label(currentLabel, systemImage: "externaldrive.badge.exclamationmark")
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private var currentLabel: String {
        let match = AppSettings.sizePresets.first { $0.bytes == settings.maxFileSizeBytes }
        return "Max size: \(match?.label ?? "Custom")"
    }
}
