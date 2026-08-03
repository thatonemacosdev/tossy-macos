import Foundation

enum JobStatus: Equatable {
    case pending
    /// `progress` is 0...1 when known (e.g. video export), or `nil` for indeterminate work.
    case converting(progress: Double?)
    /// `note` carries non-fatal info — e.g. "Hit target: 24.1 MB" or "Couldn't reach target
    /// size; smallest achievable was 31 MB".
    case done(outputURL: URL, note: String? = nil)
    case failed(String)
}

@Observable
final class ConversionJob: Identifiable {
    let id = UUID()
    let sourceURL: URL
    var status: JobStatus = .pending

    init(sourceURL: URL) {
        self.sourceURL = sourceURL
    }

    var displayName: String { sourceURL.lastPathComponent }
}
