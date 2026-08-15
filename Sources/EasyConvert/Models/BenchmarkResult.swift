import Foundation

struct BenchmarkResult: Identifiable, Codable {
    var id: String
    let domain: BenchmarkDomain
    let label: String
    let descriptionText: String
    let duration: TimeInterval
    let iterations: [TimeInterval]
    let throughput: Double?
    let unit: BenchmarkUnit
    let points: Int?
    let baselinePoints: Int
    let jitterPercentage: Double
    let detail: String
    let scoreGroup: String

    init(
        id: String = UUID().uuidString,
        domain: BenchmarkDomain,
        label: String,
        descriptionText: String = "",
        duration: TimeInterval,
        iterations: [TimeInterval] = [],
        throughput: Double?,
        unit: BenchmarkUnit,
        points: Int? = nil,
        baselinePoints: Int = 10_000,
        jitterPercentage: Double = 0.0,
        detail: String,
        scoreGroup: String
    ) {
        self.id = id
        self.domain = domain
        self.label = label
        self.descriptionText = descriptionText
        self.duration = duration
        self.iterations = iterations.isEmpty ? [duration] : iterations
        self.throughput = throughput
        self.unit = unit
        self.points = points
        self.baselinePoints = baselinePoints
        self.jitterPercentage = jitterPercentage
        self.detail = detail
        self.scoreGroup = scoreGroup
    }
}

struct BenchmarkRunReport: Identifiable, Codable {
    var id: String = UUID().uuidString
    let timestamp: Date
    let deviceModel: String
    let chipDescription: String
    let coreCount: Int
    let thermalState: String
    let overallTossyMark: Int
    let imageMark: Int
    let videoMark: Int
    let audioMark: Int
    let concurrencyMark: Int
    let stabilityIndex: Double
    let results: [BenchmarkResult]
}
