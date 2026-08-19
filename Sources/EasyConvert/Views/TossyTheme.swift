import SwiftUI
import AppKit

// MARK: - Color Palette

enum TossyColor {
    static var theme: AppTheme { AppSettings.shared.appTheme }

    static var pitchBlack: Color {
        switch theme {
        case .dark: return Color.black
        case .light: return Color(white: 0.96)
        case .liquidGlass: return Color.black.opacity(0.35)
        }
    }

    static var surfaceDeep: Color {
        switch theme {
        case .dark: return Color(white: 0.04)
        case .light: return Color(white: 0.91)
        case .liquidGlass: return Color.white.opacity(0.04)
        }
    }

    static var surfaceBase: Color {
        switch theme {
        case .dark: return Color(white: 0.07)
        case .light: return Color.white
        case .liquidGlass: return Color.white.opacity(0.08)
        }
    }

    static var surfaceElevated: Color {
        switch theme {
        case .dark: return Color(white: 0.11)
        case .light: return Color(white: 0.94)
        case .liquidGlass: return Color.white.opacity(0.14)
        }
    }

    static var surfaceHighlight: Color {
        switch theme {
        case .dark: return Color(white: 0.16)
        case .light: return Color(white: 0.88)
        case .liquidGlass: return Color.white.opacity(0.22)
        }
    }

    static var surfaceHover: Color {
        switch theme {
        case .dark: return Color(white: 0.22)
        case .light: return Color(white: 0.84)
        case .liquidGlass: return Color.white.opacity(0.28)
        }
    }

    static var borderSubtle: Color {
        switch theme {
        case .dark: return Color(white: 0.15)
        case .light: return Color(white: 0.84)
        case .liquidGlass: return Color.white.opacity(0.18)
        }
    }

    static var borderMedium: Color {
        switch theme {
        case .dark: return Color(white: 0.22)
        case .light: return Color(white: 0.74)
        case .liquidGlass: return Color.white.opacity(0.30)
        }
    }

    static var borderBright: Color {
        switch theme {
        case .dark: return Color(white: 0.40)
        case .light: return Color(white: 0.58)
        case .liquidGlass: return Color.white.opacity(0.55)
        }
    }

    static var textPrimary: Color {
        switch theme {
        case .dark, .liquidGlass: return Color.white
        case .light: return Color(white: 0.10)
        }
    }

    static var textSecondary: Color {
        switch theme {
        case .dark: return Color(white: 0.65)
        case .light: return Color(white: 0.40)
        case .liquidGlass: return Color.white.opacity(0.75)
        }
    }

    static var textTertiary: Color {
        switch theme {
        case .dark: return Color(white: 0.40)
        case .light: return Color(white: 0.55)
        case .liquidGlass: return Color.white.opacity(0.50)
        }
    }

    static var textMuted: Color {
        switch theme {
        case .dark: return Color(white: 0.25)
        case .light: return Color(white: 0.70)
        case .liquidGlass: return Color.white.opacity(0.32)
        }
    }

    static var accentProminentBg: Color {
        switch theme {
        case .dark, .liquidGlass: return Color.white
        case .light: return Color.black
        }
    }

    static var accentProminentFg: Color {
        switch theme {
        case .dark, .liquidGlass: return Color.black
        case .light: return Color.white
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

// MARK: - Audio Feedback

enum TossySound {
    static func playCompletion() {
        guard AppSettings.shared.playCompletionSound else { return }
        NSSound(named: "Glass")?.play()
    }

    static func playToss() {
        guard AppSettings.shared.playCompletionSound else { return }
        NSSound(named: "Pop")?.play()
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
