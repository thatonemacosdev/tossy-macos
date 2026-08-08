import Foundation

enum BatchSummary {
    /// Generates a summary string for a set of conversion jobs, e.g.:
    /// "12 converted, 340 MB saved, 2 failed"
    static func summarize(jobs: [ConversionJob]) -> String {
        let total = jobs.count
        guard total > 0 else { return "" }

        var convertedCount = 0
        var failedCount = 0
        var totalBytesSaved: Int64 = 0

        for job in jobs {
            switch job.status {
            case .done(let outputURL, _):
                convertedCount += 1
                let sourceSize = (try? FileManager.default.attributesOfItem(atPath: job.sourceURL.path)[.size] as? Int64) ?? 0
                let outputSize = (try? FileManager.default.attributesOfItem(atPath: outputURL.path)[.size] as? Int64) ?? 0
                if sourceSize > outputSize {
                    totalBytesSaved += (sourceSize - outputSize)
                }
            case .failed:
                failedCount += 1
            default:
                break
            }
        }

        var parts: [String] = []
        if convertedCount > 0 {
            parts.append("\(convertedCount) converted")
        }
        if totalBytesSaved > 0 {
            parts.append("\(ByteSize.displayString(totalBytesSaved)) saved")
        }
        if failedCount > 0 {
            parts.append("\(failedCount) failed")
        }

        return parts.joined(separator: ", ")
    }
}
