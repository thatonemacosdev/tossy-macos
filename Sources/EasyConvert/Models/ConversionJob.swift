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

    /// Progress ticks arrive from a subprocess's `readabilityHandler`, which runs on a
    /// background queue with no ordering guarantee relative to the process's terminationHandler
    /// (Foundation can deliver a last buffered read after termination fires). Routing every
    /// update through here means a stray late tick can never resurrect a job that has already
    /// finished into a permanently-stuck "Converting…" state.
    @MainActor
    func updateProgress(_ progress: Double?) {
        switch status {
        case .done, .failed:
            return
        case .pending, .converting:
            status = .converting(progress: progress)
        }
    }
}
