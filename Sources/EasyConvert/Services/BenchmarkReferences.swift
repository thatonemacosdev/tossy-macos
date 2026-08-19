import Foundation

/// Reference calibrations and standard hardware tiers for TossyMark scoring.
///
/// Calibration Standard:
/// 10,000 TossyMark points represents an Apple M2 Mac (8-core CPU, 10-core GPU).
/// Machines that are 2x as fast score 20,000 points; machines that are half as fast score 5,000 points.
/// This open-ended scale allows direct performance comparison across all Mac generations.
enum BenchmarkReferences {
    static let baselineStandardPoints: Int = 10_000

    static let hardwareTiers: [HardwareTier] = [
        HardwareTier(name: "Intel Legacy", subtitle: "Core i5 / i7 (4-Core)", tossyMark: 3_500, isReference: false),
        HardwareTier(name: "Apple M1", subtitle: "8-Core Baseline", tossyMark: 7_800, isReference: false),
        HardwareTier(name: "Apple M2", subtitle: "Standard Reference", tossyMark: 10_000, isReference: true),
        HardwareTier(name: "Apple M3 / M4", subtitle: "M4 Air / Base Models", tossyMark: 15_800, isReference: false),
        HardwareTier(name: "Apple M4 Pro", subtitle: "14-Core Pro Workstation", tossyMark: 23_500, isReference: false),
        HardwareTier(name: "Apple M4 Max / Ultra", subtitle: "Extreme Highline", tossyMark: 36_000, isReference: false)
    ]

    /// Calibrated baseline throughput values for an M2 Mac (yielding exactly 10,000 points).
    static let referenceThroughputs: [String: Double] = [
        // Image Processing (MP/s)
        "4K Render -> JPEG (Metal GPU)": 760.0,
        "4K Render -> JPEG (CPU)": 620.0,
        "4K Render -> PNG (Metal GPU)": 310.0,
        "4K Render -> PNG (CPU)": 280.0,
        "4K Render -> HEIC (Metal GPU)": 320.0,
        "4K Render -> HEIC (CPU)": 295.0,
        "4K Render -> AVIF (Metal GPU)": 290.0,
        "4K Render -> AVIF (CPU)": 270.0,
        "Deep Lossless WebP (Method 6, Sharp YUV)": 88.0,
        "Deep Lossless JPEG XL (Effort 9, Lossless)": 36.0,
        "Deep Lossless PNG (Deflate 9, Adam7)": 56.0,
        "Multi-page PDF Document Rasterization": 70.0,

        // Video Transcoding (x Realtime Multiplier)
        "1080p30 Hardware H.264 (VideoToolbox)": 38.0,
        "1080p30 Hardware HEVC (VideoToolbox)": 28.0,
        "4K ProRes 422 Transcode": 13.5,
        "1080p Software H.264 (libx264 veryfast)": 16.5,
        "1080p Software H.264 (libx264 medium)": 7.8,
        "1080p Software WebM (libvpx-vp9 multi-threaded)": 6.5,
        "1080p Next-Gen Video (libsvtav1 AV1)": 5.0,
        "1080p Container Multiplex (MKV Transcode)": 24.5,
        "Video Filter (Yadif Deinterlace + Lanczos Downscale)": 10.5,
        "Animated WebP / GIF Generation": 9.2,

        // Audio Processing (x Realtime Multiplier)
        "Tone -> MP3 (320kbps CBR)": 295.0,
        "Tone -> AAC (256kbps)": 235.0,
        "Tone -> FLAC (Compression Level 8)": 325.0,
        "Tone -> Opus (192kbps)": 265.0,
        "Broadcast DSP (EBU R128 Loudnorm + 48kHz)": 130.0,
        "Hi-Res Resampling (192kHz 24-bit -> 44.1kHz 16-bit)": 175.0,

        // Concurrency & Multi-Core Scaling (Tasks/sec or Scaling Ratio)
        "Parallel Batch Image Throughput (16 Tasks)": 48.0,
        "Single vs Multi-Thread Scaling Efficiency": 5.5,
        "Queue Dispatch Burst Latency": 360.0,
        "Sustained Transcode Load Stability": 98.0
    ]

    /// Computes points for a test given its measured throughput.
    static func score(label: String, throughput: Double) -> Int {
        guard let ref = referenceThroughputs[label], ref > 0 else {
            // Default baseline fallback if unlisted
            return max(100, Int(throughput * 100))
        }
        let ratio = throughput / ref
        return max(100, Int(ratio * Double(baselineStandardPoints)))
    }

    /// Computes domain sub-score from an array of scored results.
    static func domainScore(for results: [BenchmarkResult], in domain: BenchmarkDomain) -> Int {
        let domainResults = (domain == .all) ? results : results.filter { $0.domain == domain }
        let validScores = domainResults.compactMap(\.points)
        guard !validScores.isEmpty else { return 0 }
        return validScores.reduce(0, +) / validScores.count
    }

    /// Computes overall composite TossyMark from all domain results.
    static func compositeScore(for results: [BenchmarkResult]) -> Int {
        let domains: [BenchmarkDomain] = [.image, .video, .audio, .concurrency]
        var domainAverages: [Int] = []
        for d in domains {
            let score = domainScore(for: results, in: d)
            if score > 0 {
                domainAverages.append(score)
            }
        }
        guard !domainAverages.isEmpty else { return 0 }
        return domainAverages.reduce(0, +) / domainAverages.count
    }

    /// Computes run stability index (0...100% where 100% means zero jitter between iterations).
    static func overallStabilityIndex(for results: [BenchmarkResult]) -> Double {
        let jitters = results.map(\.jitterPercentage)
        guard !jitters.isEmpty else { return 100.0 }
        let avgJitter = jitters.reduce(0, +) / Double(jitters.count)
        return max(0.0, min(100.0, 100.0 - avgJitter))
    }
}
