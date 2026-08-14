import Foundation
import AppKit

enum JobStatus: Equatable {
    case pending
    /// `progress` is 0...1 when known (e.g. video export), or `nil` for indeterminate work.
    /// `etaText` is a human-readable estimate of remaining time (e.g. "12s left").
    case converting(progress: Double?, etaText: String? = nil)
    /// `note` carries non-fatal info - e.g. "Hit target: 24.1 MB" or "Couldn't reach target
    /// size; smallest achievable was 31 MB".
    case done(outputURL: URL, note: String? = nil)
    case failed(String)
}

@Observable
final class ConversionJob: Identifiable {
    let id = UUID()
    let sourceURL: URL
    var status: JobStatus = .pending
    
    // Per-job overrides (when set, takes precedence over batch settings)
    var overrideImageFormat: ImageFormat? = nil
    var overrideVideoFormat: VideoFormat? = nil
    var overrideAudioFormat: AudioFormat? = nil
    var overrideQuality: Double? = nil
    var overrideTargetSizeText: String? = nil
    var overrideResizeWidthText: String? = nil
    var overrideCustomFilename: String? = nil

    private var startTime: Date?
    private var maxSeenProgress: Double = 0.0
    private var lastETASec: Double?

    init(sourceURL: URL) {
        self.sourceURL = sourceURL
    }

    var displayName: String { sourceURL.lastPathComponent }
    
    var sourceFileSizeFormatted: String {
        guard let size = try? FileManager.default.attributesOfItem(atPath: sourceURL.path)[.size] as? Int64 else {
            return ""
        }
        return ByteSize.displayString(size)
    }

    @MainActor
    func resetProgress() {
        startTime = nil
        maxSeenProgress = 0.0
        lastETASec = nil
    }

    @MainActor
    func updateProgress(_ rawProgress: Double?) {
        switch status {
        case .done, .failed:
            return
        case .pending, .converting:
            if startTime == nil {
                startTime = Date()
                maxSeenProgress = 0.0
                lastETASec = nil
            }

            var progress: Double? = nil
            var etaText: String? = nil

            if let rawProgress {
                let clamped = min(max(rawProgress, 0.0), 1.0)
                maxSeenProgress = max(maxSeenProgress, clamped)
                progress = maxSeenProgress

                if let p = progress, p > 0.01 && p < 1.0, let start = startTime {
                    let elapsed = Date().timeIntervalSince(start)
                    if elapsed > 0.5 {
                        let estimatedTotal = elapsed / p
                        let rem = max(0, estimatedTotal - elapsed)
                        let smoothedRem = lastETASec != nil ? (0.7 * lastETASec! + 0.3 * rem) : rem
                        lastETASec = smoothedRem

                        let sec = Int(ceil(smoothedRem))
                        if sec < 60 {
                            etaText = "\(sec)s left"
                        } else {
                            let min = sec / 60
                            let remSec = sec % 60
                            etaText = "\(min)m \(remSec)s left"
                        }
                    }
                }
            }

            status = .converting(progress: progress, etaText: etaText)
        }
    }
}
