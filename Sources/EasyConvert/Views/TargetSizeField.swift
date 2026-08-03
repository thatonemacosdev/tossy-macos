import SwiftUI

/// Shared "compress to fit under this size" control used by the Images/Video/Audio tabs.
/// Free-text so it accepts "25MB", "500KB", "1.2GB", or a bare number (assumed MB).
struct TargetSizeField: View {
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Target size")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField("e.g. 25MB", text: $text)
                .textFieldStyle(.roundedBorder)
                .frame(width: 110)
        }
    }
}
