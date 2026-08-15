import Foundation

struct BenchmarkResult: Identifiable {
    let id = UUID()
    let category: String
    let label: String
    let duration: TimeInterval
    let detail: String
    /// Higher-is-better raw throughput number (MP/s, realtime-multiplier, ...) used to derive
    /// a 0-100 score relative to the fastest result sharing the same `scoreGroup`.
    let metricValue: Double?
    /// Results are scored against the best `metricValue` within the same group  -  e.g. the
    /// GPU/CPU pair for one resolution+format, or "video"/"audio" as a whole.
    let scoreGroup: String
}
