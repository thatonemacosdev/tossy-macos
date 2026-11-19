import Foundation

struct SubprocessResult: Sendable {
    let exitCode: Int32
    let standardOutput: Data
    let standardError: Data

    var stdoutString: String {
        String(data: standardOutput, encoding: .utf8) ?? ""
    }

    var stderrString: String {
        String(data: standardError, encoding: .utf8) ?? ""
    }

    var isSuccess: Bool { exitCode == 0 }
}

enum SubprocessError: LocalizedError {
    case executionFailed(String)
    case nonZeroExit(Int32, String)

    var errorDescription: String? {
        switch self {
        case .executionFailed(let msg): return msg
        case .nonZeroExit(let code, let msg): return "Process exited with code \(code): \(msg)"
        }
    }
}

enum SubprocessRunner {
    /// Executes a command asynchronously with safe pipe draining, null standardInput,
    /// and cancellation termination.
    @discardableResult
    static func run(
        executableURL: URL,
        arguments: [String],
        environment: [String: String]? = nil,
        currentDirectoryURL: URL? = nil
    ) async throws -> SubprocessResult {
        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments
        if let environment { process.environment = environment }
        if let currentDirectoryURL { process.currentDirectoryURL = currentDirectoryURL }

        process.standardInput = FileHandle.nullDevice

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                process.terminationHandler = { proc in
                    let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
                    let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                    let result = SubprocessResult(
                        exitCode: proc.terminationStatus,
                        standardOutput: outData,
                        standardError: errData
                    )
                    continuation.resume(returning: result)
                }

                do {
                    try process.run()
                } catch {
                    continuation.resume(throwing: SubprocessError.executionFailed(error.localizedDescription))
                }
            }
        } onCancel: {
            if process.isRunning {
                process.terminate()
            }
        }
    }

    /// Convenience wrapper for path-based execution.
    @discardableResult
    static func run(
        executablePath: String,
        arguments: [String],
        environment: [String: String]? = nil,
        currentDirectoryURL: URL? = nil
    ) async throws -> SubprocessResult {
        try await run(
            executableURL: URL(fileURLWithPath: executablePath),
            arguments: arguments,
            environment: environment,
            currentDirectoryURL: currentDirectoryURL
        )
    }

    /// Synchronous execution helper for non-async contexts.
    @discardableResult
    static func runSync(
        executablePath: String,
        arguments: [String]
    ) -> SubprocessResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments
        process.standardInput = FileHandle.nullDevice

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        do {
            try process.run()
            process.waitUntilExit()
            let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
            let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
            return SubprocessResult(
                exitCode: process.terminationStatus,
                standardOutput: outData,
                standardError: errData
            )
        } catch {
            return SubprocessResult(
                exitCode: -1,
                standardOutput: Data(),
                standardError: Data(error.localizedDescription.utf8)
            )
        }
    }
}
