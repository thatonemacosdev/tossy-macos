import SwiftUI
import AppKit

// MARK: - Color Palette

enum TossyColor {
    static var theme: AppTheme { AppSettings.shared.appTheme }

    static var pitchBlack: Color {
        switch theme {
        case .dark: return Color.black
        case .light: return Color.white
        case .titanium: return Color(red: 0.10, green: 0.105, blue: 0.12)
        case .liquidGlass: return Color.black.opacity(0.35)
        case .midnightCobalt: return Color(red: 0.03, green: 0.05, blue: 0.09)
        case .emerald: return Color(red: 0.02, green: 0.05, blue: 0.03)
        case .solarAmber: return Color(red: 0.06, green: 0.04, blue: 0.03)
        case .hyperViolet: return Color(red: 0.05, green: 0.03, blue: 0.09)
        case .rose: return Color(red: 0.99, green: 0.96, blue: 0.97)
        case .cream: return Color(red: 0.99, green: 0.98, blue: 0.93)
        case .sage: return Color(red: 0.96, green: 0.98, blue: 0.96)
        }
    }

    static var surfaceDeep: Color {
        switch theme {
        case .dark: return Color(white: 0.04)
        case .light: return Color(white: 0.95)
        case .titanium: return Color(red: 0.13, green: 0.135, blue: 0.155)
        case .liquidGlass: return Color.white.opacity(0.04)
        case .midnightCobalt: return Color(red: 0.05, green: 0.08, blue: 0.14)
        case .emerald: return Color(red: 0.03, green: 0.08, blue: 0.05)
        case .solarAmber: return Color(red: 0.09, green: 0.06, blue: 0.04)
        case .hyperViolet: return Color(red: 0.08, green: 0.05, blue: 0.14)
        case .rose: return Color(red: 0.95, green: 0.89, blue: 0.91)
        case .cream: return Color(red: 0.94, green: 0.92, blue: 0.84)
        case .sage: return Color(red: 0.88, green: 0.93, blue: 0.89)
        }
    }

    static var surfaceBase: Color {
        switch theme {
        case .dark: return Color(white: 0.07)
        case .light: return Color(white: 0.98)
        case .titanium: return Color(red: 0.17, green: 0.175, blue: 0.20)
        case .liquidGlass: return Color.white.opacity(0.08)
        case .midnightCobalt: return Color(red: 0.07, green: 0.11, blue: 0.18)
        case .emerald: return Color(red: 0.05, green: 0.11, blue: 0.07)
        case .solarAmber: return Color(red: 0.12, green: 0.09, blue: 0.06)
        case .hyperViolet: return Color(red: 0.11, green: 0.07, blue: 0.18)
        case .rose: return Color(red: 0.97, green: 0.93, blue: 0.94)
        case .cream: return Color(red: 0.97, green: 0.95, blue: 0.89)
        case .sage: return Color(red: 0.92, green: 0.96, blue: 0.92)
        }
    }

    static var surfaceElevated: Color {
        switch theme {
        case .dark: return Color(white: 0.11)
        case .light: return Color(white: 0.92)
        case .titanium: return Color(red: 0.22, green: 0.225, blue: 0.255)
        case .liquidGlass: return Color.white.opacity(0.14)
        case .midnightCobalt: return Color(red: 0.10, green: 0.15, blue: 0.24)
        case .emerald: return Color(red: 0.07, green: 0.15, blue: 0.10)
        case .solarAmber: return Color(red: 0.17, green: 0.12, blue: 0.09)
        case .hyperViolet: return Color(red: 0.15, green: 0.10, blue: 0.24)
        case .rose: return Color(red: 0.92, green: 0.84, blue: 0.87)
        case .cream: return Color(red: 0.91, green: 0.88, blue: 0.79)
        case .sage: return Color(red: 0.84, green: 0.90, blue: 0.85)
        }
    }

    static var surfaceHighlight: Color {
        switch theme {
        case .dark: return Color(white: 0.16)
        case .light: return Color(white: 0.86)
        case .titanium: return Color(red: 0.28, green: 0.29, blue: 0.33)
        case .liquidGlass: return Color.white.opacity(0.22)
        case .midnightCobalt: return Color(red: 0.14, green: 0.21, blue: 0.33)
        case .emerald: return Color(red: 0.10, green: 0.22, blue: 0.14)
        case .solarAmber: return Color(red: 0.24, green: 0.18, blue: 0.13)
        case .hyperViolet: return Color(red: 0.22, green: 0.15, blue: 0.33)
        case .rose: return Color(red: 0.86, green: 0.75, blue: 0.80)
        case .cream: return Color(red: 0.85, green: 0.81, blue: 0.70)
        case .sage: return Color(red: 0.76, green: 0.84, blue: 0.78)
        }
    }

    static var surfaceHover: Color {
        switch theme {
        case .dark: return Color(white: 0.22)
        case .light: return Color(white: 0.80)
        case .titanium: return Color(red: 0.34, green: 0.35, blue: 0.39)
        case .liquidGlass: return Color.white.opacity(0.28)
        case .midnightCobalt: return Color(red: 0.18, green: 0.27, blue: 0.42)
        case .emerald: return Color(red: 0.13, green: 0.28, blue: 0.18)
        case .solarAmber: return Color(red: 0.30, green: 0.22, blue: 0.16)
        case .hyperViolet: return Color(red: 0.28, green: 0.20, blue: 0.42)
        case .rose: return Color(red: 0.89, green: 0.80, blue: 0.84)
        case .cream: return Color(red: 0.88, green: 0.84, blue: 0.74)
        case .sage: return Color(red: 0.80, green: 0.87, blue: 0.82)
        }
    }

    static var borderSubtle: Color {
        switch theme {
        case .dark: return Color(white: 0.16)
        case .light: return Color(white: 0.88)
        case .titanium: return Color(red: 0.32, green: 0.33, blue: 0.37).opacity(0.6)
        case .liquidGlass: return Color.white.opacity(0.18)
        case .midnightCobalt: return Color(red: 0.14, green: 0.22, blue: 0.35)
        case .emerald: return Color(red: 0.10, green: 0.26, blue: 0.15)
        case .solarAmber: return Color(red: 0.26, green: 0.18, blue: 0.12)
        case .hyperViolet: return Color(red: 0.25, green: 0.16, blue: 0.38)
        case .rose: return Color(red: 0.88, green: 0.80, blue: 0.83)
        case .cream: return Color(red: 0.86, green: 0.82, blue: 0.72)
        case .sage: return Color(red: 0.80, green: 0.87, blue: 0.82)
        }
    }

    static var borderMedium: Color {
        switch theme {
        case .dark: return Color(white: 0.26)
        case .light: return Color(white: 0.74)
        case .titanium: return Color(red: 0.45, green: 0.46, blue: 0.52).opacity(0.75)
        case .liquidGlass: return Color.white.opacity(0.30)
        case .midnightCobalt: return Color(red: 0.20, green: 0.32, blue: 0.50)
        case .emerald: return Color(red: 0.14, green: 0.38, blue: 0.22)
        case .solarAmber: return Color(red: 0.38, green: 0.26, blue: 0.16)
        case .hyperViolet: return Color(red: 0.36, green: 0.24, blue: 0.55)
        case .rose: return Color(red: 0.78, green: 0.65, blue: 0.70)
        case .cream: return Color(red: 0.74, green: 0.68, blue: 0.54)
        case .sage: return Color(red: 0.65, green: 0.76, blue: 0.68)
        }
    }

    static var borderBright: Color {
        switch theme {
        case .dark: return Color(white: 0.45)
        case .light: return Color(white: 0.40)
        case .titanium: return Color(red: 0.70, green: 0.72, blue: 0.80).opacity(0.9)
        case .liquidGlass: return Color.white.opacity(0.55)
        case .midnightCobalt: return Color(red: 0.30, green: 0.52, blue: 0.85)
        case .emerald: return Color(red: 0.20, green: 0.70, blue: 0.38)
        case .solarAmber: return Color(red: 0.75, green: 0.48, blue: 0.20)
        case .hyperViolet: return Color(red: 0.65, green: 0.40, blue: 0.90)
        case .rose: return Color(red: 0.65, green: 0.40, blue: 0.52)
        case .cream: return Color(red: 0.62, green: 0.52, blue: 0.32)
        case .sage: return Color(red: 0.40, green: 0.60, blue: 0.45)
        }
    }

    static var textPrimary: Color {
        switch theme {
        case .dark, .titanium, .liquidGlass, .midnightCobalt, .emerald, .solarAmber, .hyperViolet:
            return Color.white
        case .light:
            return Color.black
        case .rose:
            return Color(red: 0.16, green: 0.08, blue: 0.12)
        case .cream:
            return Color(red: 0.14, green: 0.11, blue: 0.06)
        case .sage:
            return Color(red: 0.08, green: 0.14, blue: 0.10)
        }
    }

    static var textSecondary: Color {
        switch theme {
        case .dark: return Color(white: 0.70)
        case .light: return Color(white: 0.32)
        case .titanium: return Color(white: 0.72)
        case .liquidGlass: return Color.white.opacity(0.75)
        case .midnightCobalt: return Color(red: 0.65, green: 0.75, blue: 0.88)
        case .emerald: return Color(red: 0.62, green: 0.82, blue: 0.68)
        case .solarAmber: return Color(red: 0.84, green: 0.72, blue: 0.62)
        case .hyperViolet: return Color(red: 0.80, green: 0.70, blue: 0.92)
        case .rose: return Color(red: 0.42, green: 0.28, blue: 0.35)
        case .cream: return Color(red: 0.40, green: 0.34, blue: 0.22)
        case .sage: return Color(red: 0.26, green: 0.38, blue: 0.28)
        }
    }

    static var textTertiary: Color {
        switch theme {
        case .dark: return Color(white: 0.45)
        case .light: return Color(white: 0.52)
        case .titanium: return Color(white: 0.48)
        case .liquidGlass: return Color.white.opacity(0.50)
        case .midnightCobalt: return Color(red: 0.42, green: 0.52, blue: 0.66)
        case .emerald: return Color(red: 0.38, green: 0.55, blue: 0.42)
        case .solarAmber: return Color(red: 0.58, green: 0.46, blue: 0.38)
        case .hyperViolet: return Color(red: 0.55, green: 0.44, blue: 0.68)
        case .rose: return Color(red: 0.58, green: 0.44, blue: 0.50)
        case .cream: return Color(red: 0.56, green: 0.50, blue: 0.36)
        case .sage: return Color(red: 0.42, green: 0.54, blue: 0.45)
        }
    }

    static var textMuted: Color {
        switch theme {
        case .dark: return Color(white: 0.28)
        case .light: return Color(white: 0.68)
        case .titanium: return Color(white: 0.32)
        case .liquidGlass: return Color.white.opacity(0.32)
        case .midnightCobalt: return Color(red: 0.26, green: 0.34, blue: 0.45)
        case .emerald: return Color(red: 0.22, green: 0.35, blue: 0.25)
        case .solarAmber: return Color(red: 0.38, green: 0.28, blue: 0.22)
        case .hyperViolet: return Color(red: 0.35, green: 0.26, blue: 0.45)
        case .rose: return Color(red: 0.72, green: 0.60, blue: 0.65)
        case .cream: return Color(red: 0.70, green: 0.64, blue: 0.52)
        case .sage: return Color(red: 0.60, green: 0.68, blue: 0.62)
        }
    }

    static var accentProminentBg: Color {
        switch theme {
        case .dark: return Color.white
        case .light: return Color.black
        case .titanium: return Color.white
        case .liquidGlass: return Color.white
        case .midnightCobalt: return Color(red: 0.22, green: 0.55, blue: 0.98)
        case .emerald: return Color(red: 0.08, green: 0.85, blue: 0.45)
        case .solarAmber: return Color(red: 0.96, green: 0.62, blue: 0.12)
        case .hyperViolet: return Color(red: 0.72, green: 0.35, blue: 0.98)
        case .rose: return Color(red: 0.85, green: 0.25, blue: 0.45)
        case .cream: return Color(red: 0.78, green: 0.54, blue: 0.10)
        case .sage: return Color(red: 0.16, green: 0.55, blue: 0.30)
        }
    }

    static var accentProminentFg: Color {
        switch theme {
        case .dark: return Color.black
        case .light: return Color.white
        case .titanium: return Color.black
        case .liquidGlass: return Color.black
        case .midnightCobalt: return Color.white
        case .emerald: return Color(red: 0.02, green: 0.15, blue: 0.06)
        case .solarAmber: return Color(red: 0.15, green: 0.08, blue: 0.02)
        case .hyperViolet: return Color.white
        case .rose: return Color.white
        case .cream: return Color.white
        case .sage: return Color.white
        }
    }

    static let successGreen = Color(red: 0.22, green: 0.82, blue: 0.45)
    static let warningAmber = Color(red: 0.95, green: 0.72, blue: 0.20)
    static let errorRed = Color(red: 0.95, green: 0.30, blue: 0.30)
}

// MARK: - Native Visual Effect Views

struct VisualEffectBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .underWindowBackground
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow
    var state: NSVisualEffectView.State = .active

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = state
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = state
    }
}

// MARK: - Motion & Physics Tokens

enum TossyMotion {
    static let springSnappy = Animation.spring(response: 0.25, dampingFraction: 0.72)
    static let springBouncy = Animation.spring(response: 0.35, dampingFraction: 0.62)
    static let springSmooth = Animation.spring(response: 0.42, dampingFraction: 0.82)
    static let springGentle = Animation.spring(response: 0.50, dampingFraction: 0.88)

    static let easeInOut = Animation.easeInOut(duration: 0.18)
    static let easeOut = Animation.easeOut(duration: 0.22)
}

// MARK: - Audio & Haptic Feedback

enum TossyHaptic {
    static func performFeedback(_ pattern: NSHapticFeedbackManager.FeedbackPattern = .generic) {
        NSHapticFeedbackManager.defaultPerformer.perform(pattern, performanceTime: .now)
    }
}

enum TossySound {
    static func playCompletion() {
        guard AppSettings.shared.playCompletionSound else { return }
        NSSound(named: "Glass")?.play()
    }

    static func playToss() {
        guard AppSettings.shared.playCompletionSound else { return }
        NSSound(named: "Pop")?.play()
    }

    static func playStudioOpen() {
        guard AppSettings.shared.playCompletionSound else { return }
        NSSound(named: "Tink")?.play()
    }
}

// MARK: - Custom Card Modifier

struct TossyCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 12
    var isHovered: Bool = false
    var isHighlighted: Bool = false

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(isHighlighted ? TossyColor.surfaceHighlight : (isHovered ? TossyColor.surfaceElevated : TossyColor.surfaceBase))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        isHighlighted ? TossyColor.borderBright : (isHovered ? TossyColor.borderMedium : TossyColor.borderSubtle),
                        lineWidth: 1
                    )
            )
    }
}

extension View {
    func tossyCard(cornerRadius: CGFloat = 12, isHovered: Bool = false, isHighlighted: Bool = false) -> some View {
        modifier(TossyCardModifier(cornerRadius: cornerRadius, isHovered: isHovered, isHighlighted: isHighlighted))
    }
}

// MARK: - Pulsating Monochrome Progress Wave

struct TossyProgressWave: View {
    let progress: Double?

    @State private var phase: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height

            ZStack(alignment: .leading) {
                // Track
                Capsule()
                    .fill(TossyColor.surfaceElevated)

                if let progress {
                    let fillWidth = max(height, width * CGFloat(min(max(progress, 0), 1.0)))

                    ZStack {
                        Capsule()
                            .fill(TossyColor.accentProminentBg)

                        // Shimmer sweep
                        LinearGradient(
                            colors: [
                                TossyColor.accentProminentBg.opacity(0.3),
                                TossyColor.accentProminentBg,
                                TossyColor.accentProminentBg.opacity(0.3)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .mask(Capsule())
                    }
                    .frame(width: fillWidth)
                    .animation(TossyMotion.springSmooth, value: progress)
                } else {
                    // Indeterminate pulsating beam
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    TossyColor.accentProminentBg.opacity(0.05),
                                    TossyColor.accentProminentBg.opacity(0.9),
                                    TossyColor.accentProminentBg.opacity(0.05)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(40, width * 0.35))
                        .offset(x: phase * (width - max(40, width * 0.35)))
                        .onAppear {
                            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                                phase = 1.0
                            }
                        }
                }
            }
        }
        .frame(height: 6)
    }
}

// MARK: - Reusable Pill / Badge

struct TossyPill: View {
    let text: String
    var icon: String? = nil
    var isSelected: Bool = false
    var isSubtle: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
            }
            Text(text)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(isSelected ? TossyColor.accentProminentBg : (isSubtle ? TossyColor.surfaceDeep : TossyColor.surfaceElevated))
        )
        .overlay(
            Capsule()
                .strokeBorder(isSelected ? TossyColor.accentProminentBg : TossyColor.borderSubtle, lineWidth: 1)
        )
        .foregroundStyle(isSelected ? TossyColor.accentProminentFg : (isSubtle ? TossyColor.textSecondary : TossyColor.textPrimary))
    }
}

// MARK: - Tossy Interactive Icon Button

struct TossyIconButton: View {
    let icon: String
    var title: String? = nil
    var tooltip: String? = nil
    var isProminent: Bool = false
    let action: () -> Void

    @State private var isHovered = false
    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                if let title {
                    Text(title)
                        .font(.system(size: 12, weight: .medium))
                }
            }
            .padding(.horizontal, title != nil ? 10 : 7)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isProminent ? TossyColor.accentProminentBg : (isHovered ? TossyColor.surfaceHighlight : TossyColor.surfaceElevated))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(isProminent ? TossyColor.accentProminentBg : (isHovered ? TossyColor.borderMedium : TossyColor.borderSubtle), lineWidth: 1)
            )
            .foregroundStyle(isProminent ? TossyColor.accentProminentFg : (isHovered ? TossyColor.textPrimary : TossyColor.textSecondary))
            .scaleEffect(isPressed ? 0.94 : (isHovered ? 1.03 : 1.0))
            .animation(TossyMotion.springSnappy, value: isHovered)
            .animation(TossyMotion.springSnappy, value: isPressed)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .help(tooltip ?? title ?? "")
    }
}

// MARK: - Completed Output Drag-Away Chip

struct TossyDragChip: View {
    let url: URL
    let note: String?

    @State private var isHovered = false
    @State private var isDragging = false

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.up.forward.app.fill")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(isHovered ? TossyColor.textPrimary : TossyColor.textSecondary)

                Text(url.lastPathComponent)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(TossyColor.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 160)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(isHovered ? TossyColor.surfaceHighlight : TossyColor.surfaceElevated)
            )
            .overlay(
                Capsule()
                    .strokeBorder(isHovered ? TossyColor.borderBright : TossyColor.borderMedium, lineWidth: 1)
            )
            .draggable(url)
            .help("Drag file anywhere (Finder, Desktop, Mail, etc.)")
            .scaleEffect(isHovered ? 1.03 : 1.0)
            .animation(TossyMotion.springSnappy, value: isHovered)
            .onHover { isHovered = $0 }

            Button {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            } label: {
                Image(systemName: "folder")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(TossyColor.textSecondary)
                    .padding(5)
                    .background(Circle().fill(TossyColor.surfaceElevated))
            }
            .buttonStyle(.plain)
            .help("Reveal in Finder")
        }
    }
}

// MARK: - Liquid Glass Effects

struct TossyGlassModifier: ViewModifier {
    var cornerRadius: CGFloat = 12
    var interactive: Bool = true

    func body(content: Content) -> some View {
        if AppSettings.shared.appTheme == .liquidGlass {
            content
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5)
                )
                .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
        } else {
            content
        }
    }
}

extension View {
    func tossyGlassEffect(cornerRadius: CGFloat = 12, interactive: Bool = true) -> some View {
        modifier(TossyGlassModifier(cornerRadius: cornerRadius, interactive: interactive))
    }
}

struct TossyGlassContainer<Content: View>: View {
    var cornerRadius: CGFloat = 14
    @ViewBuilder let content: () -> Content

    var body: some View {
        if AppSettings.shared.appTheme == .liquidGlass {
            content()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.75)
                )
                .shadow(color: Color.black.opacity(0.18), radius: 12, x: 0, y: 6)
        } else {
            content()
                .background(TossyColor.surfaceDeep, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(TossyColor.borderSubtle, lineWidth: 1)
                )
        }
    }
}
