import SwiftUI

struct DropZoneView: View {
    let isTargeted: Bool
    var icon: String = "photo.badge.arrow.down"
    var title: String = "Toss images here to convert"
    var subtitle: String = "PNG, JPEG, HEIC, TIFF, BMP, GIF, WebP, RAW camera files, and more"
    var formatTags: [String] = ["PNG", "JPEG", "WebP", "HEIC", "AVIF", "JXL", "RAW"]
    let browseAction: () -> Void

    @State private var isHovered = false

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
                                        (AppSettings.shared.appTheme == .liquidGlass ? Color.white : TossyColor.accentProminentBg).opacity(isTargeted ? 0.28 : 0.12),
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

                    if AppSettings.shared.appTheme == .liquidGlass {
                        Circle()
                            .fill(Color.white.opacity(isTargeted ? 0.12 : (isHovered ? 0.08 : 0.05)))
                            .frame(width: circleSize, height: circleSize)
                            .overlay(
                                Circle()
                                    .strokeBorder(Color.white.opacity(isTargeted ? 0.16 : 0.06), lineWidth: 1.0)
                            )
                            .shadow(color: Color.black.opacity(0.16), radius: 8, y: 3)
                    } else {
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
                    }
                    
                    Image(systemName: icon)
                        .font(.system(size: iconFontSize, weight: .light))
                        .foregroundStyle(
                            isTargeted ? TossyColor.textPrimary :
                            (isHovered ? TossyColor.textPrimary : TossyColor.textSecondary)
                        )
                        .frame(width: circleSize, height: circleSize, alignment: .center)
                }
                .frame(width: circleSize, height: circleSize)
                .scaleEffect(isTargeted ? 1.12 : (isHovered ? 1.04 : 1.0))
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

                Button(action: {
                    TossyHaptic.performFeedback(.generic)
                    browseAction()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: round(13 * scaleMultiplier), weight: .medium))
                        Text("Browse Files…")
                            .font(.system(size: round(13 * scaleMultiplier), weight: .semibold))
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .padding(.horizontal, round(16 * scaleMultiplier))
                    .padding(.vertical, round(8 * scaleMultiplier))
                }
                .buttonStyle(.plain)
                .background(
                    Capsule()
                        .fill(TossyColor.accentProminentBg)
                )
                .foregroundStyle(TossyColor.accentProminentFg)
                .clipShape(Capsule())
                .shadow(
                    color: isTargeted ? TossyColor.accentProminentBg.opacity(0.4) : Color.black.opacity(0.25),
                    radius: isTargeted ? 12 : 5,
                    y: 2
                )

                // Format pills with guaranteed horizontal layout (no vertical character wrapping)
                if !formatTags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: round(6 * scaleMultiplier)) {
                            ForEach(formatTags, id: \.self) { tag in
                                tagPill(tag, scale: scaleMultiplier)
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                    .frame(maxWidth: max(280, subtitleMaxWidth + 60))
                    .padding(.top, round(4 * scaleMultiplier))
                }
                
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                if AppSettings.shared.appTheme == .liquidGlass {
                    ZStack {
                        // Simple optical glass tint platter
                        RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                            .fill(Color.white.opacity(isTargeted ? 0.10 : (isHovered ? 0.07 : 0.045)))

                        // Soft dashed guideline (only visible when files are actively dragged over)
                        if isTargeted {
                            RoundedRectangle(cornerRadius: max(8, cardCornerRadius - 8), style: .continuous)
                                .strokeBorder(
                                    style: StrokeStyle(lineWidth: 1.5, dash: [8, 5])
                                )
                                .foregroundStyle(Color.white.opacity(0.35))
                                .padding(8)
                        }
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                            .strokeBorder(Color.white.opacity(isTargeted ? 0.16 : 0.06), lineWidth: 1.0)
                    )
                    .shadow(
                        color: Color.black.opacity(isTargeted ? 0.25 : (isHovered ? 0.18 : 0.12)),
                        radius: isTargeted ? 20 : (isHovered ? 14 : 10),
                        x: 0,
                        y: isTargeted ? 8 : (isHovered ? 5 : 3)
                    )
                } else {
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
                        .background(
                            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                                .fill(
                                    isTargeted ? TossyColor.surfaceHighlight :
                                    (isHovered ? TossyColor.surfaceBase.opacity(0.95) : TossyColor.surfaceDeep.opacity(0.85))
                                )
                        )
                }
            }
            .padding(round(16 * scaleMultiplier))
            .scaleEffect(isTargeted ? 1.015 : 1.0)
            .animation(TossyMotion.springBouncy, value: isTargeted)
            .animation(TossyMotion.springSnappy, value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
        }
    }

    private func tagPill(_ tag: String, scale: CGFloat) -> some View {
        let fontSize: CGFloat = round(11 * scale)
        let padH: CGFloat = round(8 * scale)
        let padV: CGFloat = round(4 * scale)
        let isGlass = AppSettings.shared.appTheme == .liquidGlass
        return Text(tag)
            .font(.system(size: fontSize, weight: .medium, design: .monospaced))
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .foregroundStyle(isGlass ? Color.white.opacity(0.70) : TossyColor.textSecondary)
            .padding(.horizontal, padH)
            .padding(.vertical, padV)
            .background(
                Capsule()
                    .fill(isGlass ? Color.white.opacity(0.06) : TossyColor.surfaceElevated.opacity(0.85))
            )
            .overlay(
                Capsule()
                    .strokeBorder(
                        isGlass ?
                        AnyShapeStyle(Color.white.opacity(0.06)) :
                        AnyShapeStyle(TossyColor.borderSubtle.opacity(0.5)),
                        lineWidth: 1
                    )
            )
    }
}
