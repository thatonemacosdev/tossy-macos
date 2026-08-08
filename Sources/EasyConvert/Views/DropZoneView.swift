import SwiftUI

struct DropZoneView: View {
    let isTargeted: Bool
    var icon: String = "photo.badge.arrow.down"
    var title: String = "Toss images here to convert"
    var subtitle: String = "PNG, JPEG, HEIC, TIFF, BMP, GIF, WebP, RAW camera files, and more"
    let browseAction: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.secondary)

            Text(title)
                .font(.title3)
                .fontWeight(.medium)

            Text(subtitle)
                .font(.callout)
                .foregroundStyle(.secondary)

            Button("Browse…", action: browseAction)
                .buttonStyle(.borderedProminent)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                .foregroundStyle(isTargeted ? Color.accentColor : Color.secondary.opacity(0.4))
        )
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isTargeted ? Color.accentColor.opacity(0.08) : Color.clear)
        )
        .padding(24)
        .animation(.easeInOut(duration: 0.15), value: isTargeted)
    }
}
