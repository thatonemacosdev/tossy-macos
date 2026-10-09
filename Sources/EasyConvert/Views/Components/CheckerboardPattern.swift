import SwiftUI
import AppKit

enum ComparisonBackdrop: String, CaseIterable, Identifiable {
    case checkerboard = "Checkerboard"
    case dark = "Dark"
    case light = "Light"
    case green = "Chroma Green"

    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .checkerboard: return "checkerboard.rectangle"
        case .dark: return "moon.fill"
        case .light: return "sun.max.fill"
        case .green: return "circle.fill"
        }
    }
}

/// Renders a fast, GPU-accelerated checkerboard transparency pattern.
struct CheckerboardPattern: View {
    var size: CGFloat = 12
    var color1: Color = Color(white: 0.16)
    var color2: Color = Color(white: 0.24)
    
    var body: some View {
        Canvas { context, canvasSize in
            let cols = Int(ceil(canvasSize.width / size))
            let rows = Int(ceil(canvasSize.height / size))
            
            for row in 0..<rows {
                for col in 0..<cols {
                    let rect = CGRect(
                        x: CGFloat(col) * size,
                        y: CGFloat(row) * size,
                        width: size,
                        height: size
                    )
                    let isEven = (row + col) % 2 == 0
                    context.fill(Path(rect), with: .color(isEven ? color1 : color2))
                }
            }
        }
    }
}

struct ComparisonBackdropView: View {
    let backdrop: ComparisonBackdrop
    
    var body: some View {
        switch backdrop {
        case .checkerboard:
            CheckerboardPattern()
        case .dark:
            TossyColor.pitchBlack
        case .light:
            Color.white
        case .green:
            Color(red: 0.0, green: 0.85, blue: 0.25)
        }
    }
}
