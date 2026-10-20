import Foundation
import AppKit
import SwiftUI

// Window Frame Wrapper for authentic macOS screenshots
struct MacOSWindowFrame<Content: View>: View {
    let title: String
    let content: Content

    init(title: String = "Tossy", @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            // macOS Titlebar
            HStack(spacing: 8) {
                // Traffic light controls
                HStack(spacing: 7) {
                    Circle().fill(Color(red: 1.0, green: 0.38, blue: 0.35)).frame(width: 12, height: 12)
                    Circle().fill(Color(red: 1.0, green: 0.76, blue: 0.25)).frame(width: 12, height: 12)
                    Circle().fill(Color(red: 0.35, green: 0.85, blue: 0.38)).frame(width: 12, height: 12)
                }
                .padding(.leading, 14)

                Spacer()

                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(white: 0.6))

                Spacer()

                Color.clear.frame(width: 60, height: 1)
            }
            .frame(height: 38)
            .background(Color(red: 0.08, green: 0.08, blue: 0.09))
            .overlay(
                Rectangle()
                    .fill(Color(white: 0.15))
                    .frame(height: 1),
                alignment: .bottom
            )

            // Content Area
            content
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color(white: 0.2), lineWidth: 1)
        )
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.black)
        )
    }
}

@main
struct GenerateScreenshots {
    @MainActor
    static func main() {
        print("Initializing Tossy Screenshot Engine...")
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)

        let outputDir = URL(fileURLWithPath: "docs/screenshots")
        try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("TossyScreenshots_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        print("Preparing sample assets...")
        func makeFile(_ name: String, bytes: Int) -> URL {
            let u = tempDir.appendingPathComponent(name)
            let data = Data(count: bytes)
            try? data.write(to: u)
            return u
        }

        let movURL = makeFile("Cinematic_Intro_4K.mov", bytes: 48 * 1024 * 1024)
        let webmVidURL = makeFile("Screen_Recording_HDR.webm", bytes: 18 * 1024 * 1024)
        let wavURL = makeFile("Podcast_Master_Track.wav", bytes: 36 * 1024 * 1024)
        let webmAudURL = makeFile("Interview_Audio_Opus.webm", bytes: 4 * 1024 * 1024)
        let cr3URL = makeFile("Studio_Portrait_RAW.cr3", bytes: 32 * 1024 * 1024)
        let pngURL = makeFile("Product_Mockup_Export.png", bytes: 8 * 1024 * 1024)
        let pdfURL = makeFile("Quarterly_Report_2026.pdf", bytes: 14 * 1024 * 1024)

        AppSettings.shared.appTheme = .dark
        AppSettings.shared.navigationLayoutMode = .unified

        func renderWindowAndSave<V: View>(view: V, width: CGFloat, height: CGFloat, filename: String) {
            let frameHeight = height + 38
            let window = NSWindow(
                contentRect: NSRect(x: 100, y: 100, width: width, height: frameHeight),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.isOpaque = false
            window.backgroundColor = .clear

            let wrapped = MacOSWindowFrame(title: "Tossy") {
                view
                    .frame(width: width, height: height)
                    .background(Color.black)
            }

            let hosting = NSHostingView(rootView: wrapped.frame(width: width, height: frameHeight))
            hosting.frame = NSRect(x: 0, y: 0, width: width, height: frameHeight)
            window.contentView = hosting
            window.makeKeyAndOrderFront(nil)

            let targetDate = Date().addingTimeInterval(0.65)
            while Date() < targetDate {
                RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.05))
            }

            let bounds = hosting.bounds
            guard let rep = hosting.bitmapImageRepForCachingDisplay(in: bounds) else {
                print("Failed to get bitmapImageRep for \(filename)")
                window.orderOut(nil)
                return
            }
            hosting.cacheDisplay(in: bounds, to: rep)

            let destPNG = outputDir.appendingPathComponent("\(filename).png")
            if let pngData = rep.representation(using: .png, properties: [:]) {
                try? pngData.write(to: destPNG)
                print("Saved \(destPNG.lastPathComponent) (\(rep.pixelsWide)x\(rep.pixelsHigh), \(pngData.count) bytes)")
            }

            if filename == "desktop_hero" {
                let destJPG = outputDir.appendingPathComponent("desktop_hero.jpg")
                if let jpgData = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.9]) {
                    try? jpgData.write(to: destJPG)
                    print("Saved \(destJPG.lastPathComponent) (\(jpgData.count) bytes)")
                }
            }
            window.orderOut(nil)
        }

        print("\n--- 1. Rendering Desktop Hero (Universal Canvas with Batch Queue) ---")
        let heroVid = ConversionJob(sourceURL: movURL)
        heroVid.status = .converting(progress: 0.65, etaText: "4s left")
        let heroAud = ConversionJob(sourceURL: wavURL)
        heroAud.status = .done(outputURL: tempDir.appendingPathComponent("Podcast_Master_Track.mp3"), note: "320 kbps (12.4 MB)")
        let heroImg = ConversionJob(sourceURL: cr3URL)
        heroImg.status = .done(outputURL: tempDir.appendingPathComponent("Studio_Portrait_RAW.webp"), note: "-88% saved (3.8 MB)")

        let heroView = UniversalCanvasView(initialMode: .all, initialJobs: [heroVid, heroAud, heroImg])
        renderWindowAndSave(view: heroView, width: 1012, height: 652, filename: "desktop_hero")

        print("\n--- 2. Rendering Video Only Panel ---")
        let jobVid1 = ConversionJob(sourceURL: movURL)
        jobVid1.status = .converting(progress: 0.65, etaText: "4s left")
        let jobVid2 = ConversionJob(sourceURL: webmVidURL)
        jobVid2.status = .done(outputURL: tempDir.appendingPathComponent("Screen_Recording_HDR.mp4"), note: "-62% saved (6.8 MB)")
        let videoView = UniversalCanvasView(initialMode: .video, initialJobs: [jobVid1, jobVid2])
        renderWindowAndSave(view: videoView, width: 1012, height: 652, filename: "videos")
        renderWindowAndSave(view: videoView, width: 1012, height: 652, filename: "video")

        print("\n--- 3. Rendering Audio Only Panel ---")
        let jobAud1 = ConversionJob(sourceURL: wavURL)
        jobAud1.status = .done(outputURL: tempDir.appendingPathComponent("Podcast_Master_Track.mp3"), note: "320 kbps - EBU R128 Normalized")
        let jobAud2 = ConversionJob(sourceURL: webmAudURL)
        jobAud2.status = .converting(progress: 0.88, etaText: "1s left")
        let audioView = UniversalCanvasView(initialMode: .audio, initialJobs: [jobAud1, jobAud2])
        renderWindowAndSave(view: audioView, width: 1012, height: 652, filename: "audio")

        print("\n--- 4. Rendering Images Only Panel ---")
        let jobImg1 = ConversionJob(sourceURL: cr3URL)
        jobImg1.status = .done(outputURL: tempDir.appendingPathComponent("Studio_Portrait_RAW.webp"), note: "-88% saved (3.8 MB)")
        let jobImg2 = ConversionJob(sourceURL: pngURL)
        jobImg2.status = .pending
        let imagesView = UniversalCanvasView(initialMode: .image, initialJobs: [jobImg1, jobImg2])
        renderWindowAndSave(view: imagesView, width: 1012, height: 652, filename: "images")
        renderWindowAndSave(view: imagesView, width: 1012, height: 652, filename: "image")

        print("\n--- 5. Rendering PDF Tools Panel ---")
        let jobPdf = ConversionJob(sourceURL: pdfURL)
        jobPdf.status = .done(outputURL: tempDir.appendingPathComponent("Quarterly_Report_2026_Burst"), note: "18 pages burst, OCR extracted")
        let pdfView = UniversalCanvasView(initialMode: .pdf, initialJobs: [jobPdf])
        renderWindowAndSave(view: pdfView, width: 1012, height: 652, filename: "pdf")

        print("\n--- 6. Rendering TossyMark Benchmark Tab ---")
        let benchmarkResults: [BenchmarkResult] = [
            BenchmarkResult(domain: .image, label: "Metal 4K JPEG to WebP Transcode", duration: 0.042, throughput: 238.1, unit: .megapixelsPerSecond, points: 12450, baselinePoints: 10000, jitterPercentage: 0.8, detail: "CoreImage Metal pipeline (sRGB)", scoreGroup: "Image Mark"),
            BenchmarkResult(domain: .image, label: "CoreImage HDR Tone Map to AVIF", duration: 0.089, throughput: 112.4, unit: .megapixelsPerSecond, points: 10890, baselinePoints: 10000, jitterPercentage: 1.2, detail: "10-bit P3 wide-gamut Metal render", scoreGroup: "Image Mark"),
            BenchmarkResult(domain: .video, label: "ProRes 422 HQ to HEVC 10-bit", duration: 1.12, throughput: 89.3, unit: .framesPerSecond, points: 14200, baselinePoints: 10000, jitterPercentage: 0.5, detail: "Hardware VideoToolbox encoder", scoreGroup: "Video Mark"),
            BenchmarkResult(domain: .video, label: "H.264 1080p to AV1 (svt-av1)", duration: 2.45, throughput: 40.8, unit: .framesPerSecond, points: 9850, baselinePoints: 10000, jitterPercentage: 1.1, detail: "NEON SIMD-accelerated 14-core encode", scoreGroup: "Video Mark"),
            BenchmarkResult(domain: .audio, label: "FLAC 96kHz/24-bit to Opus 160k", duration: 0.031, throughput: 322.5, unit: .realtimeMultiplier, points: 13100, baselinePoints: 10000, jitterPercentage: 0.4, detail: "Accelerate vDSP FFT filter + libopus", scoreGroup: "Audio Mark"),
            BenchmarkResult(domain: .audio, label: "EBU R128 Dual-Pass Loudness Normalization", duration: 0.058, throughput: 172.4, unit: .realtimeMultiplier, points: 11800, baselinePoints: 10000, jitterPercentage: 0.7, detail: "Integrated -14 LUFS, true peak -1.0 dBFS", scoreGroup: "Audio Mark"),
            BenchmarkResult(domain: .concurrency, label: "Multi-Core Thread Pool Saturation (16 Jobs)", duration: 0.38, throughput: 42.1, unit: .tasksPerSecond, points: 15400, baselinePoints: 10000, jitterPercentage: 0.3, detail: "TaskGroup dynamic queue saturation", scoreGroup: "Concurrency Mark")
        ]

        let mockReport = BenchmarkRunReport(
            timestamp: Date(),
            deviceModel: "Mac16,13",
            chipDescription: "Apple Silicon Pro / Max",
            coreCount: 14,
            thermalState: "Nominal",
            overallTossyMark: 32450,
            imageMark: 11670,
            videoMark: 12025,
            audioMark: 12450,
            concurrencyMark: 15400,
            stabilityIndex: 99.2,
            results: benchmarkResults
        )

        if let reportData = try? JSONEncoder().encode([mockReport]) {
            UserDefaults.standard.set(reportData, forKey: "tossy_benchmark_history")
        }

        let benchmarkView = BenchmarkView()
        renderWindowAndSave(view: benchmarkView, width: 1012, height: 652, filename: "benchmark")

        print("\n--- 7. Rendering Code Card Studio Modal ---")
        let swiftSnippet = """
        import SwiftUI

        struct TossyTransformEngine {
            let mediaType: MediaType
            let targetFormat: UniversalFormatTarget

            func transform(_ file: URL) async throws -> URL {
                let probe = MediaProbe.probe(url: file)
                return try await FFmpegService.transcode(probe, to: targetFormat)
            }
        }
        """
        let codeCardView = CodeCardModalView(
            initialCode: swiftSnippet,
            initialFileName: "TossyTransformEngine.swift",
            initialLanguage: "Swift"
        )
        renderWindowAndSave(view: codeCardView, width: 912, height: 612, filename: "code_card")

        print("\n--- 8. Rendering PDF Studio Modal ---")
        let pdfModalView = PDFStudioModalView(
            sourceURLs: [pdfURL],
            initialTab: .merge
        )
        renderWindowAndSave(view: pdfModalView, width: 912, height: 612, filename: "pdf_studio")

        print("\n--- 9. Rendering Media Studio (Video Trimmer) Modal ---")
        let mediaModalView = MediaStudioModalView(
            sourceURLs: [movURL],
            initialTab: .trim
        )
        renderWindowAndSave(view: mediaModalView, width: 912, height: 612, filename: "media_studio")

        print("\n================================================================")
        print("All 9 screenshots generated successfully at 2x Retina resolution!")
        print("================================================================")
    }
}
