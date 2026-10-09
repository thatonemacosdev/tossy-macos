import SwiftUI
import AppKit

/// Renders an authentic, machined brushed titanium finish with horizontal micro-grain striations,
/// anisotropic reflection sweeps, and chamfered specular highlights.
struct BrushedTitaniumBackground: View {
    var isSubtle: Bool = false
    
    var body: some View {
        ZStack {
            // 1. Base metallic multi-stop anisotropic gradient (Titanium Grade 5 alloy luster)
            LinearGradient(
                stops: [
                    .init(color: Color(red: 0.16, green: 0.165, blue: 0.185), location: 0.0),
                    .init(color: Color(red: 0.11, green: 0.115, blue: 0.13), location: 0.22),
                    .init(color: Color(red: 0.21, green: 0.215, blue: 0.24), location: 0.44), // Primary specular sheen
                    .init(color: Color(red: 0.14, green: 0.145, blue: 0.165), location: 0.56),
                    .init(color: Color(red: 0.18, green: 0.185, blue: 0.21), location: 0.78), // Secondary reflected sheen
                    .init(color: Color(red: 0.09, green: 0.095, blue: 0.11), location: 1.0)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // 2. Cross-directional ambient luster
            LinearGradient(
                stops: [
                    .init(color: Color.white.opacity(0.06), location: 0.0),
                    .init(color: Color.clear, location: 0.35),
                    .init(color: Color.white.opacity(0.05), location: 0.70),
                    .init(color: Color.black.opacity(0.20), location: 1.0)
                ],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
            .blendMode(.overlay)
            
            // 3. Procedural Brushed Grain Striations (Fine horizontal brushed hairline texture)
            BrushedMetalGrainView()
                .opacity(isSubtle ? 0.35 : 0.60)
                .blendMode(.overlay)
            
            // 4. Subtle ambient rim vignette
            RadialGradient(
                colors: [Color.clear, Color.black.opacity(0.35)],
                center: .center,
                startRadius: 280,
                endRadius: 900
            )
        }
        .ignoresSafeArea()
    }
}

/// Fast procedural brushed grain renderer drawing microscopic horizontal hairlines in Metal.
struct BrushedMetalGrainView: View {
    var body: some View {
        Canvas { context, size in
            let width = size.width
            let height = size.height
            guard width > 0 && height > 0 else { return }
            
            // Deterministic pseudo-random sequence for non-flickering, razor-sharp hairlines
            var y: CGFloat = 0.0
            var seed: UInt32 = 20260828
            
            while y < height {
                seed = seed &* 1664525 &+ 1013904223
                let step = CGFloat(seed % 3 + 2) // 2 to 4px spacing between micro-scratches
                y += step
                
                seed = seed &* 1664525 &+ 1013904223
                let alpha = Double(seed % 35 + 12) / 1000.0 // 0.012 to 0.047 opacity
                
                seed = seed &* 1664525 &+ 1013904223
                let isLight = (seed % 2 == 0)
                let strokeColor = isLight ? Color.white.opacity(alpha) : Color.black.opacity(alpha * 1.3)
                
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: width, y: y))
                context.stroke(path, with: .color(strokeColor), lineWidth: 0.65)
            }
        }
    }
}

/// View modifier for brushed titanium card surface with machined bevels
struct BrushedTitaniumCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 12
    var isElevated: Bool = false
    
    @Environment(\.colorScheme) private var colorScheme
    private var isTitanium: Bool { AppSettings.shared.appTheme == .titanium }
    
    func body(content: Content) -> some View {
        if isTitanium {
            content
                .background(
                    ZStack {
                        // Machined metal billet gradient
                        LinearGradient(
                            stops: [
                                .init(color: Color(red: 0.22, green: 0.225, blue: 0.25), location: 0.0),
                                .init(color: Color(red: 0.16, green: 0.165, blue: 0.19), location: 0.45),
                                .init(color: Color(red: 0.12, green: 0.125, blue: 0.145), location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        
                        // Subtle horizontal micro-grain on card
                        BrushedMetalGrainView()
                            .opacity(0.35)
                            .blendMode(.overlay)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                )
                .overlay(
                    // Machined specular rim bevel: bright hairline top, recessed bottom
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                stops: [
                                    .init(color: Color.white.opacity(0.38), location: 0.0),
                                    .init(color: Color.white.opacity(0.12), location: 0.40),
                                    .init(color: Color.black.opacity(0.45), location: 1.0)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: Color.black.opacity(isElevated ? 0.35 : 0.18), radius: isElevated ? 8 : 4, y: isElevated ? 4 : 2)
        } else {
            content
        }
    }
}

extension View {
    func brushedTitaniumCard(cornerRadius: CGFloat = 12, isElevated: Bool = false) -> some View {
        self.modifier(BrushedTitaniumCardModifier(cornerRadius: cornerRadius, isElevated: isElevated))
    }
}
