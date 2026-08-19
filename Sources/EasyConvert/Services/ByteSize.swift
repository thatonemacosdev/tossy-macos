import Foundation

/// Parses free-text size fields like "25MB", "500 KB", "1.5gb", or a bare number (assumed MB).
enum ByteSize {
    static func parse(_ text: String) -> Int64? {
        let trimmed = text.trimmingCharacters(in: .whitespaces).lowercased()
        guard !trimmed.isEmpty else { return nil }

        var numberPart = ""
        var unitPart = ""
        for char in trimmed {
            if char.isNumber || char == "." {
                numberPart.append(char)
            } else if !char.isWhitespace {
                unitPart.append(char)
            }
        }
        guard let number = Double(numberPart), number > 0 else { return nil }

        let multiplier: Double
        switch unitPart {
        case "", "m", "mb": multiplier = 1_000_000
        case "mib": multiplier = 1024 * 1024
        case "k", "kb": multiplier = 1_000
        case "kib": multiplier = 1024
        case "g", "gb": multiplier = 1_000_000_000
        case "gib": multiplier = 1024 * 1024 * 1024
        case "b", "bytes": multiplier = 1
        default: return nil
        }
        return Int64(number * multiplier)
    }

    static func displayString(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
