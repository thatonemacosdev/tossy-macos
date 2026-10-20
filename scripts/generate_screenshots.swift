import Foundation
import AppKit
import SwiftUI

// Window Frame Wrapper for realistic macOS screenshots
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
                .padding(.leading, 12)

                Spacer()

                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(white: 0.6))

                Spacer()

                // Balancing spacer
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
        let outputDir = URL(fileURLWithPath: "docs/screenshots")
        try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("TossyScreenshots_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        print("Preparing mock sample files...")
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

        // Ensure settings are clean dark mode
        AppSettings.shared.appTheme = .dark
        AppSettings.shared.navigationLayoutMode = .unified

        func renderAndSave<V: View>(view: V, width: CGFloat, height: CGFloat, filename: String) {
            let wrapped = MacOSWindowFrame(title: "Tossy") {
                view
                    .frame(width: width, height: height)
                    .background(Color.black)
            }
            .frame(width: width, height: height + 38)
            .padding(16)
            .background(Color.clear)

            let renderer = ImageRenderer(content: wrapped)
            renderer.scale = 2.0
            guard let cgImg = renderer.cgImage else {
                print("Failed to get cgImage for \(filename)")
                return
            }

            let rep = NSBitmapImageRep(cgImage: cgImg)
            let destPNG = outputDir.appendingPathComponent("\(filename).png")
            if let pngData = rep.representation(using: .png, properties: [:]) {
                try? pngData.write(to: destPNG)
                print("Saved \(destPNG.lastPathComponent) (\(cgImg.width)x\(cgImg.height), \(pngData.count) bytes)")
            }

            if filename == "desktop_hero" {
                let destJPG = outputDir.appendingPathComponent("desktop_hero.jpg")
                if let jpgData = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.9]) {
                    try? jpgData.write(to: destJPG)
                    print("Saved \(destJPG.lastPathComponent) (\(jpgData.count) bytes)")
                }
            }
        }

        print("\n--- 1. Rendering Desktop Hero (Empty Universal Canvas) ---")
        let heroView = UniversalCanvasView(initialMode: .all)
        renderAndSave(view: heroView, width: 980, height: 620, filename: "desktop_hero")

        print("\n--- 2. Rendering Video Only Panel ---")
        let jobVid1 = ConversionJob(sourceURL: movURL)
        jobVid1.status = .converting(progress: 0.65, etaText: "4s left")
        let jobVid2 = ConversionJob(sourceURL: webmVidURL)
        jobVid2.status = .done(outputURL: tempDir.appendingPathComponent("Screen_Recording_HDR.mp4"), note: "-62% saved (6.8 MB)")
        let videoView = UniversalCanvasView(initialMode: .video, initialJobs: [jobVid1, jobVid2])
        renderAndSave(view: videoView, width: 980, height: 620, filename: "videos")
        renderAndSave(view: videoView, width: 980, height: 620, filename: "video")

        print("\n--- 3. Rendering Audio Only Panel ---")
        let jobAud1 = ConversionJob(sourceURL: wavURL)
        jobAud1.status = .done(outputURL: tempDir.appendingPathComponent("Podcast_Master_Track.mp3"), note: "320 kbps - EBU R128 Normalized")
        let jobAud2 = ConversionJob(sourceURL: webmAudURL)
        jobAud2.status = .converting(progress: 0.88, etaText: "1s left")
        let audioView = UniversalCanvasView(initialMode: .audio, initialJobs: [jobAud1, jobAud2])
        renderAndSave(view: audioView, width: 980, height: 620, filename: "audio")

        print("\n--- 4. Rendering Images Only Panel ---")
        let jobImg1 = ConversionJob(sourceURL: cr3URL)
        jobImg1.status = .done(outputURL: tempDir.appendingPathComponent("Studio_Portrait_RAW.webp"), note: "-88% saved (3.8 MB)")
        let jobImg2 = ConversionJob(sourceURL: pngURL)
        jobImg2.status = .pending
        let imagesView = UniversalCanvasView(initialMode: .image, initialJobs: [jobImg1, jobImg2])
        renderAndSave(view: imagesView, width: 980, height: 620, filename: "images")
        renderAndSave(view: imagesView, width: 980, height: 620, filename: "image")

        print("\n--- 5. Rendering PDF Tools Panel ---")
        let jobPdf = ConversionJob(sourceURL: pdfURL)
        jobPdf.status = .done(outputURL: tempDir.appendingPathComponent("Quarterly_Report_2026_Burst"), note: "18 pages burst, OCR extracted")
        let pdfView = UniversalCanvasView(initialMode: .pdf, initialJobs: [jobPdf])
        renderAndSave(view: pdfView, width: 980, height: 620, filename: "pdf")

        print("\n--- 6. Rendering TossyMark Benchmark Tab ---")
        let benchmarkView = BenchmarkView()
        renderAndSave(view: benchmarkView, width: 980, height: 620, filename: "benchmark")

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
        renderAndSave(view: codeCardView, width: 880, height: 580, filename: "code_card")

        print("\n--- 8. Rendering PDF Studio Modal ---")
        let pdfModalView = PDFStudioModalView(
            sourceURLs: [pdfURL],
            initialTab: .merge
        )
        renderAndSave(view: pdfModalView, width: 880, height: 580, filename: "pdf_studio")

        print("\n--- 9. Rendering Media Studio (Video Trimmer) Modal ---")
        let mediaModalView = MediaStudioModalView(
            sourceURLs: [movURL],
            initialTab: .trim
        )
        renderAndSave(view: mediaModalView, width: 880, height: 580, filename: "media_studio")

        print("\n================================================================")
        print("All screenshots generated successfully at 2x Retina resolution!")
        print("================================================================")
    }
}
