import SwiftUI

struct DropZoneView: View {
    let isTargeted: Bool
    var icon: String = "photo.badge.arrow.down"
    var title: String = "Toss images here to convert"
    var subtitle: String = "PNG, JPEG, HEIC, TIFF, BMP, GIF, WebP, RAW camera files, and more"
    var formatTags: [String] = ["PNG", "JPEG", "WebP", "HEIC", "AVIF", "JXL", "RAW"]
    let browseAction: () -> Void

    @State private var isHovered = false
    @State private var iconBounce = false

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            // Kinetic Animated Icon
            ZStack {
                Circle()
                    .fill(isTargeted ? Color.white.opacity(0.12) : (isHovered ? TossyColor.surfaceHighlight : TossyColor.surfaceElevated))
                    .frame(width: 88, height: 88)
                    .scaleEffect(isTargeted ? 1.15 : (isHovered ? 1.05 : 1.0))
                
                Image(systemName: icon)
                    .font(.system(size: 38, weight: .light))
                    .foregroundStyle(isTargeted ? Color.white : (isHovered ? Color.white : TossyColor.textSecondary))
                    .offset(y: iconBounce ? -4 : 0)
            }
            .animation(TossyMotion.springBouncy, value: isTargeted)
            .animation(TossyMotion.springSnappy, value: isHovered)

            VStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white)

                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(TossyColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 380)
            }

            Button("Browse Files…", action: browseAction)
                .buttonStyle(.borderedProminent)
                .tint(.white)
                .foregroundStyle(.black)
                .controlSize(.regular)
                .shadow(color: isTargeted ? Color.white.opacity(0.3) : Color.clear, radius: 8)

            // Format pills
            if !formatTags.isEmpty {
                HStack(spacing: 6) {
                    ForEach(formatTags, id: \.self) { tag in
                        TossyPill(text: tag, isSubtle: true)
                    }
                }
                .padding(.top, 4)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(
                    style: StrokeStyle(
                        lineWidth: isTargeted ? 2.5 : 1.5,
                        dash: isTargeted ? [10, 6] : [7, 5]
                    )
                )
                .foregroundStyle(isTargeted ? Color.white : (isHovered ? TossyColor.borderBright : TossyColor.borderSubtle))
        )
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(isTargeted ? Color(white: 0.12) : (isHovered ? TossyColor.surfaceBase : TossyColor.surfaceDeep))
        )
        .padding(20)
        .scaleEffect(isTargeted ? 1.015 : 1.0)
        .animation(TossyMotion.springBouncy, value: isTargeted)
        .animation(TossyMotion.springSnappy, value: isHovered)
        .onHover { hovering in
            isHovered = hovering
            withAnimation(TossyMotion.springBouncy) {
                iconBounce = hovering
            }
        }
    }
}
