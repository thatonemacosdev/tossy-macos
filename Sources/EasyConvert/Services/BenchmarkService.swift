import Foundation
import CoreImage
import ImageIO
import AVFoundation
import Metal
import UniformTypeIdentifiers

/// Generates synthetic images and video entirely on the GPU (no bundled sample assets needed)
/// and times converting them, so the app can demonstrate real throughput without user files.
final class BenchmarkService {
    private let generatorContext: CIContext = {
        if let device = MTLCreateSystemDefaultDevice() {
            return CIContext(mtlDevice: device)
        }
        return CIContext(options: nil)
    }()

    // MARK: - Image benchmark

    func runImageBenchmark(
        resolutions: [Int],
        formats: [ImageFormat],
        tempDir: URL,
        onStatus: @escaping (String) -> Void
    ) async -> [BenchmarkResult] {
        var results: [BenchmarkResult] = []
        let gpuConverter = ImageConverter(forceSoftwareRenderer: false)
        let cpuConverter = ImageConverter(forceSoftwareRenderer: true)

        for size in resolutions {
            onStatus("Generating \(size)×\(size) test image…")
            let sourceURL = tempDir.appendingPathComponent("bench_src_\(size).png")
            do {
                try writeTestImage(size: size, to: sourceURL)
            } catch {
                results.append(BenchmarkResult(category: "Image", label: "\(size)×\(size) source", duration: 0, detail: "generation failed", metricValue: nil, scoreGroup: "n/a"))
                continue
            }

            for format in formats {
                let groupKey = "image-\(size)-\(format.rawValue)"
                for (converter, engineLabel) in [(gpuConverter, "Metal GPU"), (cpuConverter, "CPU")] {
                    onStatus("Converting \(size)×\(size) → \(format.displayName) (\(engineLabel))…")
                    let start = CFAbsoluteTimeGetCurrent()
                    do {
                        let result = try await converter.convert(
                            sourceURL: sourceURL,
                            to: format,
                            quality: 0.85,
                            destinationFolder: tempDir
                        )
                        let elapsed = CFAbsoluteTimeGetCurrent() - start
                        let megapixels = Double(size * size) / 1_000_000
                        let megapixelsPerSecond = megapixels / elapsed
                        let throughput = String(format: "%.1f MP/s", megapixelsPerSecond)
                        results.append(BenchmarkResult(
                            category: "Image",
                            label: "\(size)×\(size) → \(format.displayName) (\(engineLabel))",
                            duration: elapsed,
                            detail: throughput,
                            metricValue: megapixelsPerSecond,
                            scoreGroup: groupKey
                        ))
                        result.outputURLs.forEach { try? FileManager.default.removeItem(at: $0) }
                    } catch {
                        results.append(BenchmarkResult(
                            category: "Image",
                            label: "\(size)×\(size) → \(format.displayName) (\(engineLabel))",
                            duration: 0,
                            detail: "failed",
                            metricValue: nil,
                            scoreGroup: groupKey
                        ))
                    }
                }
            }
            try? FileManager.default.removeItem(at: sourceURL)
        }
        return results
    }

    private func writeTestImage(size: Int, to url: URL) throws {
        let rect = CGRect(x: 0, y: 0, width: size, height: size)
        guard let filter = CIFilter(name: "CILinearGradient") else {
            throw ConversionError.renderFailed
        }
        filter.setValue(CIVector(x: 0, y: 0), forKey: "inputPoint0")
        filter.setValue(CIVector(x: CGFloat(size), y: CGFloat(size)), forKey: "inputPoint1")
        filter.setValue(CIColor(red: 0.98, green: 0.42, blue: 0.36), forKey: "inputColor0")
        filter.setValue(CIColor(red: 0.20, green: 0.47, blue: 0.93), forKey: "inputColor1")

        guard let output = filter.outputImage?.cropped(to: rect),
              let cgImage = generatorContext.createCGImage(output, from: rect) else {
            throw ConversionError.renderFailed
        }

        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw ConversionError.destinationCreationFailed
        }
        CGImageDestinationAddImage(destination, cgImage, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw ConversionError.writeFailed
        }
    }

    // MARK: - Video benchmark

    func runVideoBenchmark(
        formats: [VideoFormat],
        tempDir: URL,
        onStatus: @escaping (String) -> Void
    ) async -> [BenchmarkResult] {
        let clipDuration = 5.0
        let clipURL = tempDir.appendingPathComponent("bench_clip.mp4")

        onStatus("Rendering synthetic 1080p30 test clip…")
        do {
            try await writeTestClip(duration: clipDuration, size: CGSize(width: 1920, height: 1080), fps: 30, to: clipURL)
        } catch {
            return [BenchmarkResult(category: "Video", label: "synthetic clip generation", duration: 0, detail: "failed: \(error.localizedDescription)", metricValue: nil, scoreGroup: "n/a")]
        }

        let converter = VideoConverter()
        var results: [BenchmarkResult] = []

        for format in formats {
            onStatus("Transcoding 5s 1080p30 → \(format.displayName)…")
            let start = CFAbsoluteTimeGetCurrent()
            do {
                let result = try await converter.convert(sourceURL: clipURL, to: format, destinationFolder: tempDir) { _ in }
                let outputURL = result.outputURL
                let elapsed = CFAbsoluteTimeGetCurrent() - start
                let realtimeMultiplier = clipDuration / elapsed
                results.append(BenchmarkResult(
                    category: "Video",
                    label: "5s 1080p30 → \(format.displayName)",
                    duration: elapsed,
                    detail: String(format: "%.1fx realtime", realtimeMultiplier),
                    metricValue: realtimeMultiplier,
                    scoreGroup: "video"
                ))
                try? FileManager.default.removeItem(at: outputURL)
            } catch {
                results.append(BenchmarkResult(category: "Video", label: "5s 1080p30 → \(format.displayName)", duration: 0, detail: "failed", metricValue: nil, scoreGroup: "video"))
            }
        }

        try? FileManager.default.removeItem(at: clipURL)
        return results
    }

    // MARK: - Audio benchmark

    func runAudioBenchmark(
        formats: [AudioFormat],
        tempDir: URL,
        onStatus: @escaping (String) -> Void
    ) async -> [BenchmarkResult] {
        let clipDuration = 8.0
        let clipURL = tempDir.appendingPathComponent("bench_audio.wav")

        onStatus("Rendering synthetic test tone…")
        do {
            try await writeTestTone(duration: clipDuration, to: clipURL)
        } catch {
            return [BenchmarkResult(category: "Audio", label: "synthetic tone generation", duration: 0, detail: "failed: \(error.localizedDescription)", metricValue: nil, scoreGroup: "n/a")]
        }

        let converter = AudioConverter()
        var results: [BenchmarkResult] = []

        for format in formats {
            onStatus("Encoding 8s tone → \(format.displayName)…")
            let start = CFAbsoluteTimeGetCurrent()
            do {
                let result = try await converter.convert(sourceURL: clipURL, to: format, quality: 0.7, destinationFolder: tempDir) { _ in }
                let elapsed = CFAbsoluteTimeGetCurrent() - start
                let realtimeMultiplier = clipDuration / elapsed
                results.append(BenchmarkResult(
                    category: "Audio",
                    label: "8s tone → \(format.displayName)",
                    duration: elapsed,
                    detail: String(format: "%.1fx realtime", realtimeMultiplier),
                    metricValue: realtimeMultiplier,
                    scoreGroup: "audio"
                ))
                try? FileManager.default.removeItem(at: result.outputURL)
            } catch {
                results.append(BenchmarkResult(category: "Audio", label: "8s tone → \(format.displayName)", duration: 0, detail: "failed", metricValue: nil, scoreGroup: "audio"))
            }
        }

        try? FileManager.default.removeItem(at: clipURL)
        return results
    }

    private func writeTestTone(duration: TimeInterval, to url: URL) async throws {
        try? FileManager.default.removeItem(at: url)
        let sampleRate = 44_100
        let frequency = 440.0
        let sampleCount = Int(duration * Double(sampleRate))

        var samples = [Int16](repeating: 0, count: sampleCount * 2)
        for i in 0..<sampleCount {
            let value = Int16(sin(2 * .pi * frequency * Double(i) / Double(sampleRate)) * Double(Int16.max) * 0.5)
            samples[i * 2] = value
            samples[i * 2 + 1] = value
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
        appendUInt16(1) // PCM
        appendUInt16(2) // stereo
        appendUInt32(UInt32(sampleRate))
        appendUInt32(UInt32(sampleRate * 2 * 2))
        appendUInt16(4)
        appendUInt16(16)
        appendString("data")
        appendUInt32(dataSize)
        samples.withUnsafeBufferPointer { buffer in
            data.append(contentsOf: UnsafeRawBufferPointer(buffer))
        }

        try data.write(to: url)
    }

    private func writeTestClip(duration: TimeInterval, size: CGSize, fps: Int32, to url: URL) async throws {
        try? FileManager.default.removeItem(at: url)

        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(size.width),
            AVVideoHeightKey: Int(size.height)
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        input.expectsMediaDataInRealTime = false

        let pixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: Int(size.width),
            kCVPixelBufferHeightKey as String: Int(size.height)
        ]
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: pixelBufferAttributes)

        writer.add(input)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        let frameCount = Int(duration * Double(fps))
        let rect = CGRect(origin: .zero, size: size)

        for frameIndex in 0..<frameCount {
            while !input.isReadyForMoreMediaData {
                try await Task.sleep(nanoseconds: 5_000_000)
            }

            guard let pixelBufferPool = adaptor.pixelBufferPool else { throw ConversionError.renderFailed }
            var pixelBufferOut: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(nil, pixelBufferPool, &pixelBufferOut)
            guard let pixelBuffer = pixelBufferOut else { throw ConversionError.renderFailed }

            let phase = CGFloat(frameIndex) / CGFloat(max(frameCount - 1, 1))
            let ciImage = animatedFrame(rect: rect, phase: phase)
            generatorContext.render(ciImage, to: pixelBuffer)

            let presentationTime = CMTime(value: CMTimeValue(frameIndex), timescale: fps)
            adaptor.append(pixelBuffer, withPresentationTime: presentationTime)
        }

        input.markAsFinished()
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            writer.finishWriting {
                continuation.resume()
            }
        }

        if writer.status != .completed {
            throw VideoConversionError.exportFailed(writer.error?.localizedDescription ?? "Synthetic clip generation failed.")
        }
    }

    private func animatedFrame(rect: CGRect, phase: CGFloat) -> CIImage {
        guard let filter = CIFilter(name: "CILinearGradient") else {
            return CIImage(color: .blue).cropped(to: rect)
        }
        let x0 = rect.width * phase
        filter.setValue(CIVector(x: x0, y: 0), forKey: "inputPoint0")
        filter.setValue(CIVector(x: x0 + rect.width, y: rect.height), forKey: "inputPoint1")
        filter.setValue(CIColor(red: 0.98, green: 0.42, blue: 0.36), forKey: "inputColor0")
        filter.setValue(CIColor(red: 0.20, green: 0.47, blue: 0.93), forKey: "inputColor1")
        return (filter.outputImage ?? CIImage(color: .blue)).cropped(to: rect)
    }
}
