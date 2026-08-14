import SwiftUI
import AppKit

// MARK: - Color Palette

enum TossyColor {
    static let pitchBlack = Color.black
    static let surfaceDeep = Color(white: 0.04)
    static let surfaceBase = Color(white: 0.07)
    static let surfaceElevated = Color(white: 0.11)
    static let surfaceHighlight = Color(white: 0.16)
    static let surfaceHover = Color(white: 0.22)
    
    static let borderSubtle = Color(white: 0.15)
    static let borderMedium = Color(white: 0.22)
    static let borderBright = Color(white: 0.40)
    
    static let textPrimary = Color.white
    static let textSecondary = Color(white: 0.65)
    static let textTertiary = Color(white: 0.40)
    static let textMuted = Color(white: 0.25)
    
    static let accentWhite = Color.white
    static let successGreen = Color(red: 0.22, green: 0.82, blue: 0.45)
    static let warningAmber = Color(red: 0.95, green: 0.72, blue: 0.20)
    static let errorRed = Color(red: 0.95, green: 0.30, blue: 0.30)
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

// MARK: - Custom Modifiers

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
                            .fill(Color.white)
                        
                        // Shimmer sweep
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.3),
                                Color.white,
                                Color.white.opacity(0.3)
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
                                    Color.white.opacity(0.05),
                                    Color.white.opacity(0.9),
                                    Color.white.opacity(0.05)
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
                .fill(isSelected ? Color.white : (isSubtle ? TossyColor.surfaceDeep : TossyColor.surfaceElevated))
        )
        .overlay(
            Capsule()
                .strokeBorder(isSelected ? Color.white : TossyColor.borderSubtle, lineWidth: 1)
        )
        .foregroundStyle(isSelected ? Color.black : (isSubtle ? TossyColor.textSecondary : TossyColor.textPrimary))
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
                    .fill(isProminent ? Color.white : (isHovered ? TossyColor.surfaceHighlight : TossyColor.surfaceElevated))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(isProminent ? Color.white : (isHovered ? TossyColor.borderMedium : TossyColor.borderSubtle), lineWidth: 1)
            )
            .foregroundStyle(isProminent ? Color.black : (isHovered ? Color.white : TossyColor.textSecondary))
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
                    .foregroundStyle(isHovered ? Color.white : TossyColor.textSecondary)
                
                Text(url.lastPathComponent)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.white)
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
                    .strokeBorder(isHovered ? Color.white.opacity(0.8) : TossyColor.borderMedium, lineWidth: 1)
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
