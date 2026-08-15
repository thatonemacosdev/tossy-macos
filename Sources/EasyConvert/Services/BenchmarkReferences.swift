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
        HardwareTier(name: "Intel Legacy", subtitle: "Core i5 4-Core", tossyMark: 3_200, isReference: false),
        HardwareTier(name: "Apple M1", subtitle: "8-Core Baseline", tossyMark: 7_600, isReference: false),
        HardwareTier(name: "Apple M2 / M3", subtitle: "Standard Reference", tossyMark: 10_000, isReference: true),
        HardwareTier(name: "Apple M3 / M4 Pro", subtitle: "12-Core Workstation", tossyMark: 16_800, isReference: false),
        HardwareTier(name: "Apple M4 Max / Ultra", subtitle: "Extreme Highline", tossyMark: 28_500, isReference: false)
    ]

    /// Calibrated baseline throughput values for an M2 Mac (yielding exactly 10,000 points).
    static let referenceThroughputs: [String: Double] = [
        // Image Processing (MP/s)
        "4K Render -> JPEG (Metal GPU)": 380.0,
        "4K Render -> JPEG (CPU)": 320.0,
        "4K Render -> PNG (Metal GPU)": 150.0,
        "4K Render -> PNG (CPU)": 140.0,
        "4K Render -> HEIC (Metal GPU)": 160.0,
        "4K Render -> HEIC (CPU)": 150.0,
        "4K Render -> AVIF (Metal GPU)": 145.0,
        "4K Render -> AVIF (CPU)": 135.0,
        "Deep Lossless WebP (Method 6, Sharp YUV)": 42.0,
        "Deep Lossless JPEG XL (Effort 9, Lossless)": 18.0,
        "Deep Lossless PNG (Deflate 9, Adam7)": 28.0,
        "Multi-page PDF Document Rasterization": 35.0,

        // Video Transcoding (x Realtime Multiplier)
        "1080p30 Hardware H.264 (VideoToolbox)": 18.5,
        "1080p30 Hardware HEVC (VideoToolbox)": 14.0,
        "4K ProRes 422 Transcode": 6.5,
        "1080p Software H.264 (libx264 veryfast)": 8.0,
        "1080p Software H.264 (libx264 medium)": 3.8,
        "1080p Software WebM (libvpx-vp9 multi-threaded)": 3.2,
        "1080p Next-Gen Video (libsvtav1 AV1)": 2.4,
        "1080p Container Multiplex (MKV Transcode)": 12.0,
        "Video Filter (Yadif Deinterlace + Lanczos Downscale)": 5.2,
        "Animated WebP / GIF Generation": 4.5,

        // Audio Processing (x Realtime Multiplier)
        "Tone -> MP3 (320kbps CBR)": 145.0,
        "Tone -> AAC (256kbps)": 115.0,
        "Tone -> FLAC (Compression Level 8)": 160.0,
        "Tone -> Opus (192kbps)": 130.0,
        "Broadcast DSP (EBU R128 Loudnorm + 48kHz)": 65.0,
        "Hi-Res Resampling (192kHz 24-bit -> 44.1kHz 16-bit)": 85.0,

        // Concurrency & Multi-Core Scaling (Tasks/sec or Scaling Ratio)
        "Parallel Batch Image Throughput (16 Tasks)": 24.0,
        "Single vs Multi-Thread Scaling Efficiency": 3.8,
        "Queue Dispatch Burst Latency": 180.0,
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
