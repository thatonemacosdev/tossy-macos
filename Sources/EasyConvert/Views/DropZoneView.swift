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
        GeometryReader { geo in
            let scaleMultiplier: CGFloat = {
                let manual = AppSettings.shared.recordingScaleMode.baseMultiplier
                if AppSettings.shared.recordingScaleMode == .responsive {
                    let w = geo.size.width
                    let h = geo.size.height
                    let wScale = max(1.0, min(1.35, 1.0 + max(0, w - 450) / 1800.0))
                    let hScale = max(1.0, min(1.35, 1.0 + max(0, h - 360) / 1500.0))
                    return min(wScale, hScale)
                }
                return manual
            }()

            let circleSize = round(88 * scaleMultiplier)
            let iconFontSize = round(38 * scaleMultiplier)
            let titleFontSize = round(17 * scaleMultiplier)
            let subtitleFontSize = round(13 * scaleMultiplier)
            let subtitleMaxWidth = round(400 * scaleMultiplier)
            let cardCornerRadius = round(20 * scaleMultiplier)

            VStack(spacing: round(18 * scaleMultiplier)) {
                Spacer()
                
                // Kinetic Animated Icon with Specular Glow
                ZStack {
                    if isTargeted || isHovered {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        TossyColor.accentProminentBg.opacity(isTargeted ? 0.35 : 0.15),
                                        Color.clear
                                    ],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: circleSize * 0.9
                                )
                            )
                            .frame(width: circleSize * 1.5, height: circleSize * 1.5)
                            .blur(radius: 8)
                    }

                    Circle()
                        .fill(
                            isTargeted ?
                            TossyColor.accentProminentBg.opacity(0.16) :
                            (isHovered ? TossyColor.surfaceHighlight : TossyColor.surfaceElevated)
                        )
                        .frame(width: circleSize, height: circleSize)
                        .overlay(
                            Circle()
                                .strokeBorder(
                                    isTargeted ?
                                    TossyColor.accentProminentBg.opacity(0.6) :
                                    (isHovered ? TossyColor.borderMedium : TossyColor.borderSubtle),
                                    lineWidth: 1
                                )
                        )
                        .scaleEffect(isTargeted ? 1.12 : (isHovered ? 1.04 : 1.0))
                    
                    Image(systemName: icon)
                        .font(.system(size: iconFontSize, weight: .light))
                        .foregroundStyle(
                            isTargeted ? TossyColor.textPrimary :
                            (isHovered ? TossyColor.textPrimary : TossyColor.textSecondary)
                        )
                        .offset(y: iconBounce ? -5 : 0)
                }
                .animation(TossyMotion.springBouncy, value: isTargeted)
                .animation(TossyMotion.springSnappy, value: isHovered)

                VStack(spacing: round(6 * scaleMultiplier)) {
                    Text(title)
                        .font(.system(size: titleFontSize, weight: .semibold, design: .rounded))
                        .foregroundStyle(TossyColor.textPrimary)

                    Text(subtitle)
                        .font(.system(size: subtitleFontSize))
                        .foregroundStyle(TossyColor.textSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: subtitleMaxWidth)
                }

                Button(action: browseAction) {
                    HStack(spacing: 6) {
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: round(13 * scaleMultiplier), weight: .medium))
                        Text("Browse Files…")
                            .font(.system(size: round(13 * scaleMultiplier), weight: .semibold))
                    }
                    .padding(.horizontal, round(16 * scaleMultiplier))
                    .padding(.vertical, round(8 * scaleMultiplier))
                }
                .buttonStyle(.plain)
                .background(TossyColor.accentProminentBg)
                .foregroundStyle(TossyColor.accentProminentFg)
                .clipShape(RoundedRectangle(cornerRadius: round(8 * scaleMultiplier), style: .continuous))
                .shadow(
                    color: isTargeted ? TossyColor.accentProminentBg.opacity(0.4) : Color.black.opacity(0.2),
                    radius: isTargeted ? 12 : 4,
                    y: 2
                )

                // Format pills
                if !formatTags.isEmpty {
                    HStack(spacing: round(6 * scaleMultiplier)) {
                        ForEach(formatTags, id: \.self) { tag in
                            Text(tag)
                                .font(.system(size: round(11 * scaleMultiplier), weight: .medium, design: .monospaced))
                                .foregroundStyle(TossyColor.textSecondary)
                                .padding(.horizontal, round(8 * scaleMultiplier))
                                .padding(.vertical, round(3 * scaleMultiplier))
                                .background(TossyColor.surfaceElevated.opacity(0.85))
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .strokeBorder(TossyColor.borderSubtle.opacity(0.5), lineWidth: 0.5)
                                )
                        }
                    }
                    .padding(.top, round(4 * scaleMultiplier))
                }
                
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                    .strokeBorder(
                        style: StrokeStyle(
                            lineWidth: isTargeted ? 2.5 : 1.5,
                            dash: isTargeted ? [10, 6] : [7, 5]
                        )
                    )
                    .foregroundStyle(
                        isTargeted ?
                        TossyColor.accentProminentBg :
                        (isHovered ? TossyColor.borderBright : TossyColor.borderSubtle)
                    )
            )
            .background(
                RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                    .fill(
                        isTargeted ?
                        TossyColor.surfaceHighlight :
                        (isHovered ? TossyColor.surfaceBase.opacity(0.95) : TossyColor.surfaceDeep.opacity(0.85))
                    )
            )
            .padding(round(16 * scaleMultiplier))
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
}
