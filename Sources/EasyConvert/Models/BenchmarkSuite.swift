import Foundation

enum BenchmarkDomain: String, CaseIterable, Identifiable, Codable {
    case all = "All"
    case image = "Images"
    case video = "Video"
    case audio = "Audio"
    case concurrency = "Concurrency"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .image: return "photo.stack"
        case .video: return "film"
        case .audio: return "waveform"
        case .concurrency: return "cpu"
        }
    }
}

enum BenchmarkUnit: String, Codable {
    case megapixelsPerSecond = "MP/s"
    case framesPerSecond = "FPS"
    case realtimeMultiplier = "x realtime"
    case megabytesPerSecond = "MB/s"
    case tasksPerSecond = "tasks/s"
    case milliseconds = "ms"

    func format(value: Double) -> String {
        switch self {
        case .megapixelsPerSecond:
            return String(format: "%.1f MP/s", value)
        case .framesPerSecond:
            return String(format: "%.1f FPS", value)
        case .realtimeMultiplier:
            return String(format: "%.1fx realtime", value)
        case .megabytesPerSecond:
            return String(format: "%.1f MB/s", value)
        case .tasksPerSecond:
            return String(format: "%.1f tasks/s", value)
        case .milliseconds:
            return String(format: "%.1f ms", value)
        }
    }
}

struct HardwareTier: Identifiable, Codable {
    var id: String { name }
    let name: String
    let subtitle: String
    let tossyMark: Int
    let isReference: Bool
}
