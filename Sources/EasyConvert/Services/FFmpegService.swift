import Foundation

enum FFmpegError: LocalizedError {
    case notAvailable
    case processFailed(String)

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "ffmpeg isn't available. Reinstall EasyConvert or install ffmpeg via Homebrew."
        case .processFailed(let message):
            return message
        }
    }
}

/// Mutable box for accumulating a process's stderr from a `readabilityHandler` callback,
/// which runs on a background dispatch queue rather than the calling task.
private final class DataBox: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = Data()

    func append(_ chunk: Data) {
        lock.lock()
        storage.append(chunk)
        lock.unlock()
    }

    var data: Data {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }
}

/// Buffers a subprocess's piped text across multiple `readabilityHandler` calls and yields
/// only complete lines. A single read can land mid-line (e.g. "out_time_us=12" with the
/// remaining digits arriving in the next chunk); parsing that as-is would briefly report a
/// truncated, too-small progress value.
private final class LineBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var pending = ""

    func addChunk(_ text: String) -> [Substring] {
        lock.lock()
        defer { lock.unlock() }
        pending += text
        var lines = pending.split(separator: "\n", omittingEmptySubsequences: false)
        guard let last = lines.popLast() else { return [] }
        pending = String(last)
        return lines
    }
}

/// Thin async wrapper around the bundled `ffmpeg` binary that parses its `-progress pipe:1`
/// output into a 0...1 fraction as it runs.
final class FFmpegService {
    /// Runs `ffmpeg` with `arguments`, reporting progress against `totalDuration` (seconds).
    /// `-progress pipe:2 -nostats` should be included by the caller alongside `-y`.
    func run(
        arguments: [String],
        totalDuration: Double?,
        onProgress: @escaping (Double) -> Void
    ) async throws {
        guard let ffmpegPath = FFmpegLocator.ffmpegPath else { throw FFmpegError.notAvailable }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: ffmpegPath)
        process.arguments = arguments

        let progressPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = progressPipe
        process.standardError = errorPipe

        let stderrBox = DataBox()
        errorPipe.fileHandleForReading.readabilityHandler = { handle in
            stderrBox.append(handle.availableData)
        }

        let progressBuffer = LineBuffer()
        progressPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            for line in progressBuffer.addChunk(text) {
                guard line.hasPrefix("out_time_us=") else { continue }
                let value = line.dropFirst("out_time_us=".count)
                if let microseconds = Double(value), let totalDuration, totalDuration > 0 {
                    let fraction = min(max((microseconds / 1_000_000) / totalDuration, 0), 1)
                    onProgress(fraction)
                }
            }
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            process.terminationHandler = { proc in
                progressPipe.fileHandleForReading.readabilityHandler = nil
                errorPipe.fileHandleForReading.readabilityHandler = nil
                if proc.terminationStatus == 0 {
                    continuation.resume()
                } else {
                    let message = String(data: stderrBox.data, encoding: .utf8) ?? "ffmpeg failed."
                    let tail = message.split(separator: "\n").suffix(4).joined(separator: " ")
                    continuation.resume(throwing: FFmpegError.processFailed(tail.isEmpty ? "ffmpeg exited with an error." : tail))
                }
            }
            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    /// Runs `ffmpeg`/a tool synchronously to completion and returns captured stdout (used for
    /// one-shot capability queries like `-encoders`, not for actual conversions).
    static func runCapturingOutput(executablePath: String, arguments: [String]) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
        } catch {
            return ""
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(data: data, encoding: .utf8) ?? ""
    }
}
