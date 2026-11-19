import XCTest
@testable import Tossy

final class TossyTests: XCTestCase {
    func testAppVersion() {
        XCTAssertEqual(AppVersion.displayName, "Tossy 2.2")
        XCTAssertEqual(AppVersion.string, "2.2.0")
    }

    func testFormatRegistryCategories() {
        let registry = FormatRegistry.shared
        XCTAssertEqual(registry.category(forExtension: "mp4"), .video)
        XCTAssertEqual(registry.category(forExtension: "mov"), .video)
        XCTAssertEqual(registry.category(forExtension: "mkv"), .video)
        XCTAssertEqual(registry.category(forExtension: "png"), .image)
        XCTAssertEqual(registry.category(forExtension: "webp"), .image)
        XCTAssertEqual(registry.category(forExtension: "mp3"), .audio)
        XCTAssertEqual(registry.category(forExtension: "flac"), .audio)
        XCTAssertEqual(registry.category(forExtension: "pdf"), .document)
        XCTAssertEqual(registry.category(forExtension: "docx"), .document)
        XCTAssertEqual(registry.category(forExtension: "srt"), .document)
        XCTAssertEqual(registry.category(forExtension: "json"), .document)
        XCTAssertEqual(registry.category(forExtension: "zip"), .archive)
        XCTAssertEqual(registry.category(forExtension: "tar"), .archive)
    }

    func testAudioFormatAdditions() {
        let m4r = AudioFormat.m4r
        XCTAssertEqual(m4r.fileExtension, "m4r")
        XCTAssertTrue(m4r.displayName.contains("M4R"))
        XCTAssertTrue(m4r.supportsQuality)
    }

    func testVideoFormatAdditions() {
        let prores4444 = VideoFormat.movProRes4444
        XCTAssertEqual(prores4444.fileExtension, "mov")
        XCTAssertEqual(prores4444.category, .professional)

        let apng = VideoFormat.apng
        XCTAssertEqual(apng.fileExtension, "png")
        XCTAssertEqual(apng.category, .animation)

        let webmAlpha = VideoFormat.webmAlpha
        XCTAssertEqual(webmAlpha.fileExtension, "webm")
    }

    func testSubprocessRunner() async throws {
        let res = try await SubprocessRunner.run(
            executablePath: "/bin/echo",
            arguments: ["hello-tossy"]
        )
        XCTAssertTrue(res.isSuccess)
        XCTAssertEqual(res.stdoutString.trimmingCharacters(in: .whitespacesAndNewlines), "hello-tossy")

        let syncRes = SubprocessRunner.runSync(
            executablePath: "/bin/echo",
            arguments: ["sync-tossy"]
        )
        XCTAssertTrue(syncRes.isSuccess)
        XCTAssertEqual(syncRes.stdoutString.trimmingCharacters(in: .whitespacesAndNewlines), "sync-tossy")
    }

    func testOutputNamingAndClaim() {
        let tmp = FileManager.default.temporaryDirectory
        let fileA = tmp.appendingPathComponent("test_source_\(UUID().uuidString).txt")
        let fileB = tmp.appendingPathComponent("test_source_\(UUID().uuidString).txt")

        let outA = OutputNaming.uniqueOutputURL(for: fileA, fileExtension: "pdf", destinationFolder: tmp)
        let outB = OutputNaming.uniqueOutputURL(for: fileB, fileExtension: "pdf", destinationFolder: tmp)

        XCTAssertNotEqual(outA.path, outB.path)
        OutputNaming.releaseClaimedPath(outA)
        OutputNaming.releaseClaimedPath(outB)
    }

    func testSubtitleConversion() async throws {
        let srtContent = """
        1
        00:00:01,000 --> 00:00:04,000
        Hello world!

        2
        00:00:05,000 --> 00:00:08,000
        Tossy 2.2 is fast.
        """
        let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent("tossy_test_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let srtURL = tmpDir.appendingPathComponent("sample.srt")
        try srtContent.write(to: srtURL, atomically: true, encoding: .utf8)

        let vttURL = try await DocumentAndDataConverterService.shared.convertSubtitle(
            sourceURL: srtURL,
            targetExtension: "vtt",
            destinationFolder: tmpDir
        )
        XCTAssertTrue(FileManager.default.fileExists(atPath: vttURL.path))
        let vttContent = try String(contentsOf: vttURL, encoding: .utf8)
        XCTAssertTrue(vttContent.contains("WEBVTT"))
        XCTAssertTrue(vttContent.contains("00:00:01.000 --> 00:00:04.000"))
        XCTAssertTrue(vttContent.contains("Hello world!"))
    }

    func testDataConversionJSONToPlist() async throws {
        let json = """
        {
            "name": "Tossy",
            "version": "2.2.0",
            "speed": 100
        }
        """
        let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent("tossy_data_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let jsonURL = tmpDir.appendingPathComponent("data.json")
        try json.write(to: jsonURL, atomically: true, encoding: .utf8)

        let plistURL = try await DocumentAndDataConverterService.shared.convertData(
            sourceURL: jsonURL,
            targetExtension: "plist",
            destinationFolder: tmpDir
        )
        XCTAssertTrue(FileManager.default.fileExists(atPath: plistURL.path))
        let plistData = try Data(contentsOf: plistURL)
        let propertyList = try PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any]
        XCTAssertEqual(propertyList?["name"] as? String, "Tossy")
        XCTAssertEqual(propertyList?["version"] as? String, "2.2.0")
    }
}
