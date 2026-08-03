import Foundation

/// Absolute scoring reference points, keyed by benchmark test label.
///
/// Each value is this benchmark suite's own measured throughput on a baseline machine
/// (Apple M4 MacBook Air) divided by 0.70 — i.e. the baseline machine scores exactly 70 on
/// every test by construction. Faster machines score above 70 (up to 100, the assumed
/// practical ceiling — about 43% faster than the baseline); slower machines score below.
/// This makes scores comparable *across runs and machines*, not just within a single run.
enum BenchmarkReferences {
    static let values: [String: Double] = [
        "512×512 → JPEG (Metal GPU)": 61.8179,
        "512×512 → JPEG (CPU)": 111.1904,
        "512×512 → HEIC (Metal GPU)": 10.2567,
        "512×512 → HEIC (CPU)": 18.7659,
        "512×512 → PNG (Metal GPU)": 61.7353,
        "512×512 → PNG (CPU)": 72.6602,
        "512×512 → AVIF (Metal GPU)": 16.1607,
        "512×512 → AVIF (CPU)": 28.7033,
        "1024×1024 → JPEG (Metal GPU)": 225.3277,
        "1024×1024 → JPEG (CPU)": 185.6464,
        "1024×1024 → HEIC (Metal GPU)": 60.5510,
        "1024×1024 → HEIC (CPU)": 53.6310,
        "1024×1024 → PNG (Metal GPU)": 124.0030,
        "1024×1024 → PNG (CPU)": 129.8635,
        "1024×1024 → AVIF (Metal GPU)": 82.6826,
        "1024×1024 → AVIF (CPU)": 98.6547,
        "2048×2048 → JPEG (Metal GPU)": 360.4351,
        "2048×2048 → JPEG (CPU)": 360.0890,
        "2048×2048 → HEIC (Metal GPU)": 132.9044,
        "2048×2048 → HEIC (CPU)": 133.9593,
        "2048×2048 → PNG (Metal GPU)": 169.2712,
        "2048×2048 → PNG (CPU)": 171.6763,
        "2048×2048 → AVIF (Metal GPU)": 158.6912,
        "2048×2048 → AVIF (CPU)": 155.7299,
        "4096×4096 → JPEG (Metal GPU)": 432.5705,
        "4096×4096 → JPEG (CPU)": 436.0407,
        "4096×4096 → HEIC (Metal GPU)": 202.3800,
        "4096×4096 → HEIC (CPU)": 205.3641,
        "4096×4096 → PNG (Metal GPU)": 197.6454,
        "4096×4096 → PNG (CPU)": 201.6375,
        "4096×4096 → AVIF (Metal GPU)": 209.7677,
        "4096×4096 → AVIF (CPU)": 204.2407,
        "5s 1080p30 → MP4 (H.264)": 307.6695,
        "5s 1080p30 → MP4 (HEVC)": 9.3052,
        "5s 1080p30 → MOV (ProRes 422)": 29.5714,
        "5s 1080p30 → MKV (H.264 + AAC)": 9.2883,
        "5s 1080p30 → WebM (VP9 + Opus)": 3.4628,
        "8s tone → MP3": 109.8585,
        "8s tone → AAC": 75.5029,
        "8s tone → FLAC": 140.2245,
        "8s tone → Opus": 101.5638
    ]

    /// Score 0...100 for `label` given a measured `value`, or `nil` if this label has no
    /// reference point (falls back to relative scoring in that case).
    static func score(label: String, value: Double) -> Int? {
        guard let reference = values[label], reference > 0 else { return nil }
        return min(100, Int((value / reference) * 100))
    }
}
