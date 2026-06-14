import Foundation

public struct ExternalAdapter: Adapter {
    public init() {}

    public func activate(targetID: String, target: TargetConfig, context: RuntimeContext) -> AdapterResult {
        guard let command = target.run ?? target.command, !command.isEmpty else {
            return .error("external adapter target '\(targetID)' requires 'run' or 'command'")
        }

        let payload = ExternalAdapterPayload(
            targetID: targetID,
            target: target.fields,
            runtime: ExternalAdapterRuntime(
                dryRun: context.dryRun,
                verbose: context.verbose,
                quiet: context.quiet
            )
        )

        let input: Data
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            input = try encoder.encode(payload)
        } catch {
            return .error("failed to encode external adapter payload for '\(targetID)': \(error)")
        }

        var env = context.environment.merging(target.env ?? [:]) { _, new in new }
        env["KEYROUTE_TARGET"] = targetID
        env["KEYROUTE_ADAPTER"] = target.adapter
        env["KEYROUTE_DRY_RUN"] = context.dryRun ? "1" : "0"
        env["KEYROUTE_VERBOSE"] = context.verbose ? "1" : "0"
        env["KEYROUTE_QUIET"] = context.quiet ? "1" : "0"

        if context.dryRun {
            return .success("dry-run: would execute external adapter \(command) \((target.args ?? []).joined(separator: " "))")
        }

        let result = CommandRunner().runDetailed(
            executable: command,
            arguments: target.args ?? [],
            cwd: target.cwd,
            environment: env,
            quiet: context.quiet,
            stdin: input,
            captureOutput: true
        )

        return externalResult(
            targetID: targetID,
            command: command,
            result: result
        )
    }

    public func externalResult(targetID: String, command: String, result: CommandRunResult) -> AdapterResult {
        let fallback = "external adapter '\(command)' exited with status \(result.status)"
        if let structured = structuredOutput(result: result) {
            let message = structured.message ?? defaultStructuredMessage(status: structured.status, targetID: targetID, fallback: fallback)
            if let status = structured.status {
                return adapterResult(status: status, message: message, exitCode: structured.exitCode)
            }
            return adapterResult(processStatus: result.status, targetID: targetID, message: message, fallback: fallback)
        }

        let message = externalMessage(result: result, fallback: fallback)
        return adapterResult(processStatus: result.status, targetID: targetID, message: message, fallback: fallback)
    }

    private func adapterResult(processStatus: Int32, targetID: String, message: String, fallback: String) -> AdapterResult {
        switch processStatus {
        case 0:
            return .success(message.isEmpty ? "external target '\(targetID)' completed" : message)
        case ExitCode.notFound.value:
            return .notFound(message)
        case ExitCode.permissionDenied.value:
            return .permissionDenied(message)
        default:
            return .error(message.isEmpty ? fallback : message, exitCode: .raw(Int(processStatus)))
        }
    }

    private func adapterResult(status: AdapterStatus, message: String, exitCode: Int?) -> AdapterResult {
        let code = exitCode.map(ExitCode.raw)
        switch status {
        case .success:
            return AdapterResult(status: .success, message: message, exitCode: code ?? .success)
        case .notFound:
            return AdapterResult(status: .notFound, message: message, exitCode: code ?? .notFound)
        case .permissionDenied:
            return AdapterResult(status: .permissionDenied, message: message, exitCode: code ?? .permissionDenied)
        case .error:
            return AdapterResult(status: .error, message: message, exitCode: code ?? .adapterError)
        }
    }

    private func defaultStructuredMessage(status: AdapterStatus?, targetID: String, fallback: String) -> String {
        switch status {
        case .success:
            return "external target '\(targetID)' completed"
        case .notFound:
            return "external target '\(targetID)' not found"
        case .permissionDenied:
            return "external target '\(targetID)' permission denied"
        case .error, .none:
            return fallback
        }
    }

    private func structuredOutput(result: CommandRunResult) -> ExternalAdapterStructuredOutput? {
        for data in [result.stderr, result.stdout] {
            guard let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  text.hasPrefix("{"),
                  let payload = text.data(using: .utf8),
                  let output = try? JSONDecoder().decode(ExternalAdapterStructuredOutput.self, from: payload) else {
                continue
            }
            return output
        }
        return nil
    }

    private func externalMessage(result: CommandRunResult, fallback: String) -> String {
        let stderr = String(data: result.stderr, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !stderr.isEmpty {
            return stderr
        }
        let stdout = String(data: result.stdout, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !stdout.isEmpty {
            return stdout
        }
        return result.status == 0 ? "" : fallback
    }
}

public struct ExternalAdapterPayload: Encodable {
    let targetID: String
    let target: [String: ConfigValue]
    let runtime: ExternalAdapterRuntime
}

public struct ExternalAdapterRuntime: Encodable {
    let dryRun: Bool
    let verbose: Bool
    let quiet: Bool
}

public struct ExternalAdapterStructuredOutput: Decodable {
    let status: AdapterStatus?
    let message: String?
    let exitCode: Int?
}
