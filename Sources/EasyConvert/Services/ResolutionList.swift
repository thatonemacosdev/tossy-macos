import Foundation

/// Parses a free-text list of widths like "1024, 512, 256" for multi-resolution export.
enum ResolutionList {
    static func parse(_ text: String) -> [Int] {
        text
            .split(whereSeparator: { $0 == "," || $0 == " " })
            .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            .filter { $0 > 0 }
    }
}
