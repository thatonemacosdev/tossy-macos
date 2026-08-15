import Foundation
import CoreImage
import ImageIO
import AVFoundation
import UniformTypeIdentifiers
import Metal

@main
struct TestHarness {
    static var passedCount = 0
    static var failedCount = 0
    static var skippedCount = 0
    static var failures: [String] = []

    static func main() async {
        print("=======================================================")
        print("Tossy 1.4.0 Clientside Integration and Stress Test Suite")
        print("=======================================================")

        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("TossyTestHarness_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // 1. Generate Base Test Media
        print("\n[Phase 1] Generating Synthetic Test Assets...")
        guard let imageURL = try? createTestImage(size: 512, in: tempDir) else {
            print("FAILED to create test image")
            exit(1)
        }
        print("  - Generated 512x512 PNG test image: \(imageURL.path)")

        guard let toneURL = try? createTestTone(duration: 2.0, in: tempDir) else {
            print("FAILED to create test audio tone")
            exit(1)
        }
        print("  - Generated 2.0s 44.1kHz stereo WAV test tone: \(toneURL.path)")

        guard let clipURL = try? await createTestClip(duration: 2.0, size: CGSize(width: 640, height: 360), fps: 30, in: tempDir) else {
            print("FAILED to create test video clip")
            exit(1)
        }
        print("  - Generated 2.0s 360p30 MP4 test clip: \(clipURL.path)")

        // 2. Test All Image Formats
        print("\n[Phase 2] Testing Every Image Format Conversion...")
        let imageConverter = ImageConverter()
        for format in ImageFormat.allCases {
            await runTest("Image -> \(format.displayName)") {
                guard format.isAvailable else {
                    skip("Format \(format.displayName) unavailable on this system")
                    return
                }
                let outFolder = tempDir.appendingPathComponent("img_\(format.rawValue)")
                try FileManager.default.createDirectory(at: outFolder, withIntermediateDirectories: true)
                let res = try await imageConverter.convert(
                    sourceURL: imageURL,
                    to: format,
                    quality: 0.85,
                    destinationFolder: outFolder
                )
                assertCondition(!res.outputURLs.isEmpty, "No output files returned")
                for url in res.outputURLs {
                    assertFileValid(url)
                }
            }
        }

        // 3. Test Image CLI Knobs
        print("\n[Phase 3] Testing Image CLI Knobs & Deep Encoding Options...")
        
        // WebP Knobs
        await runTest("WebP Lossless Mode") {
            AppSettings.shared.webpConfig.isLossless = true
            let res = try await imageConverter.convert(sourceURL: imageURL, to: .webp, destinationFolder: tempDir)
            assertFileValid(res.outputURLs.first)
            AppSettings.shared.webpConfig.isLossless = false
        }

        await runTest("WebP Method 6 + Sharp YUV + Drawing Preset + Filter Strength 75") {
            AppSettings.shared.webpConfig.isLossless = false
            AppSettings.shared.webpConfig.method = 6
            AppSettings.shared.webpConfig.sharpYuv = true
            AppSettings.shared.webpConfig.preset = "drawing"
            AppSettings.shared.webpConfig.filterStrength = 75
            let res = try await imageConverter.convert(sourceURL: imageURL, to: .webp, destinationFolder: tempDir)
            assertFileValid(res.outputURLs.first)
        }

        // JPEG XL Knobs
        await runTest("JPEG XL Lossless Mode") {
            guard ImageFormat.jxl.isAvailable else { skip("jxl unavailable"); return }
            AppSettings.shared.jxlConfig.isLossless = true
            let res = try await imageConverter.convert(sourceURL: imageURL, to: .jxl, destinationFolder: tempDir)
            assertFileValid(res.outputURLs.first)
            AppSettings.shared.jxlConfig.isLossless = false
        }

        await runTest("JPEG XL Effort 9 + Distance 1.2 + Faster Decoding 2") {
            guard ImageFormat.jxl.isAvailable else { skip("jxl unavailable"); return }
            AppSettings.shared.jxlConfig.isLossless = false
            AppSettings.shared.jxlConfig.effort = 9
            AppSettings.shared.jxlConfig.distance = 1.2
            AppSettings.shared.jxlConfig.fasterDecoding = 2
            let res = try await imageConverter.convert(sourceURL: imageURL, to: .jxl, destinationFolder: tempDir)
            assertFileValid(res.outputURLs.first)
        }

        // JPEG Progressive & Chroma 4:4:4
        await runTest("JPEG Progressive + Chroma Subsampling 4:4:4") {
            AppSettings.shared.jpegConfig.isProgressive = true
            AppSettings.shared.jpegConfig.chromaSubsampling = "4:4:4"
            let res = try await imageConverter.convert(sourceURL: imageURL, to: .jpeg, destinationFolder: tempDir)
            assertFileValid(res.outputURLs.first)
        }

        // PNG Deflate 9 & Adam7 Interlacing
        await runTest("PNG Deflate Level 9 + Adam7 Interlaced") {
            AppSettings.shared.pngConfig.compressionLevel = 9
            AppSettings.shared.pngConfig.isInterlaced = true
            let res = try await imageConverter.convert(sourceURL: imageURL, to: .png, destinationFolder: tempDir)
            assertFileValid(res.outputURLs.first)
        }

        // TIFF Schemes
        for scheme in ["LZW", "Deflate", "PackBits", "None"] {
            await runTest("TIFF Compression: \(scheme)") {
                AppSettings.shared.tiffConfig.compression = scheme
                let res = try await imageConverter.convert(sourceURL: imageURL, to: .tiff, destinationFolder: tempDir)
                assertFileValid(res.outputURLs.first)
            }
        }

        // GIF Max Colors & Dithering
        await runTest("GIF Max Colors 64 + Floyd-Steinberg Dithering") {
            AppSettings.shared.gifConfig.maxColors = 64
            AppSettings.shared.gifConfig.dither = true
            let res = try await imageConverter.convert(sourceURL: imageURL, to: .gif, destinationFolder: tempDir)
            assertFileValid(res.outputURLs.first)
        }

        // Target Size & Resize Width
        await runTest("Image Target Size Fitting (under 30KB)") {
            let targetBytes: Int64 = 30 * 1024
            let res = try await imageConverter.convert(
                sourceURL: imageURL,
                to: .jpeg,
                destinationFolder: tempDir,
                targetSizeBytes: targetBytes
            )
            assertFileValid(res.outputURLs.first)
            assertCondition(res.note != nil, "Missing target size note in result")
        }

        await runTest("Image Explicit Resize Width (128px)") {
            let res = try await imageConverter.convert(
                sourceURL: imageURL,
                to: .png,
                destinationFolder: tempDir,
                targetWidth: 128
            )
            let outURL = res.outputURLs.first!
            assertFileValid(outURL)
            if let imgSource = CGImageSourceCreateWithURL(outURL as CFURL, nil),
               let props = CGImageSourceCopyPropertiesAtIndex(imgSource, 0, nil) as? [CFString: Any],
               let width = props[kCGImagePropertyPixelWidth] as? Int {
                assertCondition(width == 128, "Expected width 128, got \(width)")
            }
        }

        // 4. Test All Video Formats
        print("\n[Phase 4] Testing Every Video Format Conversion...")
        AppSettings.shared.videoConfig = VideoConfig()
        let videoConverter = VideoConverter()
        for format in VideoFormat.allCases {
            await runTest("Video -> \(format.displayName)") {
                guard format.isAvailable else {
                    skip("Format \(format.displayName) unavailable on this system")
                    return
                }
                let outFolder = tempDir.appendingPathComponent("vid_\(format.rawValue)")
                try FileManager.default.createDirectory(at: outFolder, withIntermediateDirectories: true)
                let res = try await videoConverter.convert(
                    sourceURL: clipURL,
                    to: format,
                    destinationFolder: outFolder
                ) { _ in }
                assertFileValid(res.outputURL)
            }
        }

        // 5. Test Video CLI Knobs
        print("\n[Phase 5] Testing Video CLI Knobs & Parameters...")
        
        await runTest("Video CRF 28 + Speed Ultrafast + Scale Bicubic") {
            AppSettings.shared.videoConfig.encodingMode = "crf"
            AppSettings.shared.videoConfig.crfValue = 28
            AppSettings.shared.videoConfig.x264Preset = "ultrafast"
            AppSettings.shared.videoConfig.scalingAlgorithm = "bicubic"
            AppSettings.shared.videoConfig.frameRate = "24"
            let res = try await videoConverter.convert(sourceURL: clipURL, to: .mkv, destinationFolder: tempDir) { _ in }
            assertFileValid(res.outputURL)
        }

        await runTest("Video 10-bit YUV420P10LE Pixel Format") {
            AppSettings.shared.videoConfig.pixelFormat = "yuv420p10le"
            let res = try await videoConverter.convert(sourceURL: clipURL, to: .mkv, destinationFolder: tempDir) { _ in }
            assertFileValid(res.outputURL)
            AppSettings.shared.videoConfig.pixelFormat = "yuv420p"
        }

        await runTest("Video Audio Stream: Opus & Deinterlace filter") {
            AppSettings.shared.videoConfig.audioCodec = "opus"
            AppSettings.shared.videoConfig.deinterlace = true
            let res = try await videoConverter.convert(sourceURL: clipURL, to: .mkv, destinationFolder: tempDir) { _ in }
            assertFileValid(res.outputURL)
        }

        await runTest("Video Audio Mute (none)") {
            AppSettings.shared.videoConfig.audioCodec = "none"
            let res = try await videoConverter.convert(sourceURL: clipURL, to: .webm, destinationFolder: tempDir) { _ in }
            assertFileValid(res.outputURL)
            AppSettings.shared.videoConfig.audioCodec = "auto"
        }

        await runTest("Video Target Size Fitting") {
            let res = try await videoConverter.convert(
                sourceURL: clipURL,
                to: .mkv,
                destinationFolder: tempDir,
                targetSizeBytes: 250 * 1024
            ) { _ in }
            assertFileValid(res.outputURL)
            AppSettings.shared.videoConfig = VideoConfig()
        }

        // 6. Test All Audio Formats
        print("\n[Phase 6] Testing Every Audio Format Conversion...")
        let audioConverter = AudioConverter()
        for format in AudioFormat.allCases {
            await runTest("Audio -> \(format.displayName)") {
                guard format.isAvailable else {
                    skip("Format \(format.displayName) unavailable on this system")
                    return
                }
                let outFolder = tempDir.appendingPathComponent("aud_\(format.rawValue)")
                try FileManager.default.createDirectory(at: outFolder, withIntermediateDirectories: true)
                let res = try await audioConverter.convert(
                    sourceURL: toneURL,
                    to: format,
                    quality: 0.7,
                    destinationFolder: outFolder
                ) { _ in }
                assertFileValid(res.outputURL)
            }
        }

        // 7. Test Audio CLI Knobs
        print("\n[Phase 7] Testing Audio CLI Knobs & Parameters...")
        
        await runTest("Audio VBR Mode Quality 0 + 48kHz + Stereo + EBU R128") {
            AppSettings.shared.audioConfig.bitrateMode = "vbr"
            AppSettings.shared.audioConfig.vbrQuality = 0
            AppSettings.shared.audioConfig.sampleRateHz = "48000"
            AppSettings.shared.audioConfig.channels = "stereo"
            AppSettings.shared.audioConfig.normalizeEBUR128 = true
            let res = try await audioConverter.convert(sourceURL: toneURL, to: .mp3, destinationFolder: tempDir) { _ in }
            assertFileValid(res.outputURL)
        }

        await runTest("Audio CBR 320kbps + Mono Downmix") {
            AppSettings.shared.audioConfig.bitrateMode = "cbr"
            AppSettings.shared.audioConfig.cbrBitrateKbps = 320
            AppSettings.shared.audioConfig.channels = "mono"
            AppSettings.shared.audioConfig.normalizeEBUR128 = false
            let res = try await audioConverter.convert(sourceURL: toneURL, to: .aac, destinationFolder: tempDir) { _ in }
            assertFileValid(res.outputURL)
            AppSettings.shared.audioConfig.channels = "keep"
        }

        await runTest("Audio Lossless 24-bit PCM") {
            AppSettings.shared.audioConfig.losslessBitDepth = "24"
            let res = try await audioConverter.convert(sourceURL: toneURL, to: .wav, destinationFolder: tempDir) { _ in }
            assertFileValid(res.outputURL)
            AppSettings.shared.audioConfig.losslessBitDepth = "16"
        }

        await runTest("Audio FLAC Compression Level 8") {
            AppSettings.shared.audioConfig.flacCompressionLevel = 8
            let res = try await audioConverter.convert(sourceURL: toneURL, to: .flac, destinationFolder: tempDir) { _ in }
            assertFileValid(res.outputURL)
            AppSettings.shared.audioConfig.flacCompressionLevel = 5
        }

        await runTest("Audio Opus Low Delay Application Mode") {
            AppSettings.shared.audioConfig.opusApplication = "lowdelay"
            let res = try await audioConverter.convert(sourceURL: toneURL, to: .opus, destinationFolder: tempDir) { _ in }
            assertFileValid(res.outputURL)
            AppSettings.shared.audioConfig.opusApplication = "audio"
        }

        await runTest("Audio Extraction from Video Clip") {
            let res = try await audioConverter.convert(
                sourceURL: clipURL,
                to: .mp3,
                destinationFolder: tempDir
            ) { _ in }
            assertFileValid(res.outputURL)
            assertCondition(res.outputURL.pathExtension.lowercased() == "mp3", "Expected mp3 extension")
        }

        // 8. Test General Policies and System Integrations
        print("\n[Phase 8] Testing General App Policies, Presets & Collisions...")
        
        await runTest("File Collision: Auto-numbering (-2)") {
            OutputNaming.resetClaimedPaths()
            AppSettings.shared.fileConflictAction = .autoNumber
            let file1 = OutputNaming.uniqueOutputURL(for: imageURL, fileExtension: "png", destinationFolder: tempDir, nameSuffix: "_colTest")
            try Data("test".utf8).write(to: file1)
            let file2 = OutputNaming.uniqueOutputURL(for: imageURL, fileExtension: "png", destinationFolder: tempDir, nameSuffix: "_colTest")
            assertCondition(file1 != file2, "Paths should differ")
            assertCondition(file2.lastPathComponent.contains("-2"), "Path should contain -2")
        }

        await runTest("File Collision: Overwrite Mode") {
            OutputNaming.resetClaimedPaths()
            AppSettings.shared.fileConflictAction = .overwrite
            let file1 = OutputNaming.uniqueOutputURL(for: imageURL, fileExtension: "png", destinationFolder: tempDir, nameSuffix: "_owTest")
            try Data("initial".utf8).write(to: file1)
            let file2 = OutputNaming.uniqueOutputURL(for: imageURL, fileExtension: "png", destinationFolder: tempDir, nameSuffix: "_owTest")
            assertCondition(file1 == file2, "Overwrite mode should reuse the path")
        }

        await runTest("Presets Persistence & Store Serialization") {
            let store = PresetStore.shared
            let initialCount = store.imagePresets.count
            let p = ImagePreset(
                name: "HarnessPreset_\(UUID().uuidString)",
                formatRawValue: ImageFormat.webp.rawValue,
                quality: 0.9,
                keepOriginalFormat: false,
                targetSizeText: "50KB",
                customFilenameText: "harness_custom",
                resizeWidthText: "800",
                preserveMetadata: true
            )
            store.imagePresets.append(p)
            assertCondition(store.imagePresets.count == initialCount + 1, "Preset count should increment")
            store.imagePresets.removeAll(where: { $0.name == p.name })
            assertCondition(store.imagePresets.count == initialCount, "Preset count should return to initial")
        }

        // 9. Benchmark Service Verification (1.5.0 Redesign)
        print("\n[Phase 9] Testing Built-in Benchmark Service (1.5.0 Suite)...")
        let benchService = BenchmarkService()
        await runTest("Benchmark Engine: Warmup Execution") {
            await benchService.runWarmup(tempDir: tempDir) { _ in }
        }

        await runTest("Benchmark Engine: Image Benchmark Suite") {
            let res = await benchService.runImageBenchmark(tempDir: tempDir) { _ in }
            assertCondition(!res.isEmpty, "Benchmark results should not be empty")
            assertCondition(res.allSatisfy { ($0.points ?? 0) > 0 }, "All image tests should score positive points")
        }

        await runTest("Benchmark Engine: Audio Benchmark Suite") {
            let res = await benchService.runAudioBenchmark(tempDir: tempDir) { _ in }
            assertCondition(!res.isEmpty, "Audio benchmark results should not be empty")
            assertCondition(res.allSatisfy { ($0.points ?? 0) > 0 }, "All audio tests should score positive points")
        }

        await runTest("Benchmark Engine: Concurrency & Scaling Suite") {
            let res = await benchService.runConcurrencyBenchmark(tempDir: tempDir) { _ in }
            assertCondition(!res.isEmpty, "Concurrency benchmark results should not be empty")
        }

        await runTest("Benchmark Engine: Composite TossyMark Calculation") {
            let dummy = [
                BenchmarkResult(domain: .image, label: "Test 1", duration: 0.1, throughput: 300.0, unit: .megapixelsPerSecond, points: 12000, detail: "300 MP/s", scoreGroup: "g1"),
                BenchmarkResult(domain: .video, label: "Test 2", duration: 0.5, throughput: 15.0, unit: .realtimeMultiplier, points: 11000, detail: "15x", scoreGroup: "g2"),
                BenchmarkResult(domain: .audio, label: "Test 3", duration: 0.2, throughput: 100.0, unit: .realtimeMultiplier, points: 9500, detail: "100x", scoreGroup: "g3"),
                BenchmarkResult(domain: .concurrency, label: "Test 4", duration: 0.3, throughput: 20.0, unit: .tasksPerSecond, points: 10500, detail: "20 t/s", scoreGroup: "g4")
            ]
            let score = BenchmarkReferences.compositeScore(for: dummy)
            assertCondition(score > 10000 && score < 12000, "Composite score should be valid average: \(score)")
            let stability = BenchmarkReferences.overallStabilityIndex(for: dummy)
            assertCondition(stability >= 95.0, "Stability should be near 100%: \(stability)")
        }

        // 10. Summary
        print("\n=======================================================")
        print("Test Execution Summary:")
        print("  Passed:  \(passedCount)")
        print("  Failed:  \(failedCount)")
        print("  Skipped: \(skippedCount)")
        print("=======================================================")

        if failedCount > 0 {
            print("\nFAILURES:")
            for f in failures {
                print("  - \(f)")
            }
            exit(1)
        } else {
            print("\nAll integration tests passed successfully.")
        }
    }

    // MARK: - Assertion & Runner Helpers

    static func runTest(_ name: String, block: () async throws -> Void) async {
        do {
            try await block()
            passedCount += 1
            print("  [PASS] \(name)")
        } catch is SkipError {
            // handled in skip()
        } catch {
            failedCount += 1
            let msg = "\(name) failed: \(error.localizedDescription)"
            failures.append(msg)
            print("  [FAIL] \(msg)")
        }
    }

    struct SkipError: Error {}

    static func skip(_ reason: String) {
        skippedCount += 1
        print("  [SKIP] \(reason)")
    }

    static func assertCondition(_ condition: Bool, _ message: String) {
        if !condition {
            fatalError(message)
        }
    }

    static func assertFileValid(_ url: URL?) {
        guard let url else {
            fatalError("File URL is nil")
        }
        guard FileManager.default.fileExists(atPath: url.path) else {
            fatalError("File does not exist at \(url.path)")
        }
        let attrs = (try? FileManager.default.attributesOfItem(atPath: url.path)) ?? [:]
        let size = attrs[.size] as? Int64 ?? 0
        if size <= 0 {
            fatalError("File at \(url.path) has invalid size: \(size) bytes")
        }
    }

    // MARK: - Synthetic Media Generation

    static func createTestImage(size: Int, in dir: URL) throws -> URL {
        let fileURL = dir.appendingPathComponent("synth_\(size).png")
        let rect = CGRect(x: 0, y: 0, width: size, height: size)
        guard let filter = CIFilter(name: "CILinearGradient") else {
            throw NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create CIFilter"])
        }
        filter.setValue(CIVector(x: 0, y: 0), forKey: "inputPoint0")
        filter.setValue(CIVector(x: CGFloat(size), y: CGFloat(size)), forKey: "inputPoint1")
        filter.setValue(CIColor(red: 0.9, green: 0.2, blue: 0.2), forKey: "inputColor0")
        filter.setValue(CIColor(red: 0.2, green: 0.2, blue: 0.9), forKey: "inputColor1")

        let context = CIContext(options: nil)
        guard let output = filter.outputImage?.cropped(to: rect),
              let cgImage = context.createCGImage(output, from: rect) else {
            throw NSError(domain: "Test", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create CGImage"])
        }

        guard let dest = CGImageDestinationCreateWithURL(fileURL as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw NSError(domain: "Test", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to create destination"])
        }
        CGImageDestinationAddImage(dest, cgImage, nil)
        guard CGImageDestinationFinalize(dest) else {
            throw NSError(domain: "Test", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed to finalize PNG"])
        }
        return fileURL
    }

    static func createTestTone(duration: TimeInterval, in dir: URL) throws -> URL {
        let fileURL = dir.appendingPathComponent("synth_tone.wav")
        let sampleRate = 44_100
        let frequency = 440.0
        let sampleCount = Int(duration * Double(sampleRate))

        var samples = [Int16](repeating: 0, count: sampleCount * 2)
        for i in 0..<sampleCount {
            let val = Int16(sin(2 * .pi * frequency * Double(i) / Double(sampleRate)) * Double(Int16.max) * 0.5)
            samples[i * 2] = val
            samples[i * 2 + 1] = val
        }

        var data = Data()
        func appendString(_ s: String) { data.append(s.data(using: .ascii)!) }
        func appendUInt32(_ v: UInt32) { withUnsafeBytes(of: v.littleEndian) { data.append(contentsOf: $0) } }
        func appendUInt16(_ v: UInt16) { withUnsafeBytes(of: v.littleEndian) { data.append(contentsOf: $0) } }

        let dataSize = UInt32(samples.count * 2)
        appendString("RIFF")
        appendUInt32(36 + dataSize)
        appendString("WAVE")
        appendString("fmt ")
        appendUInt32(16)
        appendUInt16(1)
        appendUInt16(2)
        appendUInt32(UInt32(sampleRate))
        appendUInt32(UInt32(sampleRate * 2 * 2))
        appendUInt16(4)
        appendUInt16(16)
        appendString("data")
        appendUInt32(dataSize)
        samples.withUnsafeBufferPointer { buffer in
            data.append(contentsOf: UnsafeRawBufferPointer(buffer))
        }

        try data.write(to: fileURL)
        return fileURL
    }

    static func createTestClip(duration: TimeInterval, size: CGSize, fps: Int32, in dir: URL) async throws -> URL {
        let fileURL = dir.appendingPathComponent("synth_clip.mp4")
        try? FileManager.default.removeItem(at: fileURL)

        guard let ffmpegPath = FFmpegLocator.ffmpegPath else {
            throw NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "ffmpeg not available"])
        }

        let args = [
            "-y",
            "-f", "lavfi",
            "-i", "testsrc=duration=\(duration):size=\(Int(size.width))x\(Int(size.height)):rate=\(fps)",
            "-f", "lavfi",
            "-i", "sine=frequency=440:duration=\(duration)",
            "-c:v", "libx264",
            "-pix_fmt", "yuv420p",
            "-c:a", "aac",
            "-b:a", "128k",
            fileURL.path
        ]

        let process = Process()
        process.executableURL = URL(fileURLWithPath: ffmpegPath)
        process.arguments = args
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 && FileManager.default.fileExists(atPath: fileURL.path) else {
            throw NSError(domain: "Test", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to generate test clip with audio"])
        }
        return fileURL
    }
}
