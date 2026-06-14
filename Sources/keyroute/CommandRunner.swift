import Foundation

struct CommandRunResult {
    let status: Int32
    let stdout: Data
    let stderr: Data
}

struct CommandRunner {
    func run(
        executable: String,
        arguments: [String] = [],
        cwd: String? = nil,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        quiet: Bool = false,
        stdin: Data? = nil,
        captureOutput: Bool = false
    ) -> Int32 {
        runDetailed(
            executable: executable,
            arguments: arguments,
            cwd: cwd,
            environment: environment,
            quiet: quiet,
            stdin: stdin,
            captureOutput: captureOutput
        ).status
    }

    func runDetailed(
        executable: String,
        arguments: [String] = [],
        cwd: String? = nil,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        quiet: Bool = false,
        stdin: Data? = nil,
        captureOutput: Bool = false
    ) -> CommandRunResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: expandedPath(executable))
        process.arguments = arguments
        process.environment = environment
        if let cwd {
            process.currentDirectoryURL = URL(fileURLWithPath: expandedPath(cwd))
        }

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        if quiet || captureOutput {
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe
        }

        let stdinPipe = Pipe()
        if stdin != nil {
            process.standardInput = stdinPipe
        }

        do {
            try process.run()
            if let stdin {
                stdinPipe.fileHandleForWriting.write(stdin)
                try? stdinPipe.fileHandleForWriting.close()
            }
            process.waitUntilExit()
            let stdout = (quiet || captureOutput) ? stdoutPipe.fileHandleForReading.readDataToEndOfFile() : Data()
            let stderr = (quiet || captureOutput) ? stderrPipe.fileHandleForReading.readDataToEndOfFile() : Data()
            return CommandRunResult(status: process.terminationStatus, stdout: stdout, stderr: stderr)
        } catch {
            fputs("\(error.localizedDescription)\n", stderr)
            return CommandRunResult(status: 127, stdout: Data(), stderr: Data(error.localizedDescription.utf8))
        }
    }
}
