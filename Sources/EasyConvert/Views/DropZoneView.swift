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
                .tint(.white)
                .foregroundStyle(.black)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                .foregroundStyle(isTargeted ? Color.white : Color(white: 0.3))
        )
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isTargeted ? Color(white: 0.15) : Color(white: 0.06))
        )
        .padding(24)
        .animation(.easeInOut(duration: 0.15), value: isTargeted)
    }
}
