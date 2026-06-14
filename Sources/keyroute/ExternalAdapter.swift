import Foundation

struct ExternalAdapter: Adapter {
    func activate(targetID: String, target: TargetConfig, context: RuntimeContext) -> AdapterResult {
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

        let message = externalMessage(result: result, fallback: "external adapter '\(command)' exited with status \(result.status)")
        switch result.status {
        case 0:
            return .success(message.isEmpty ? "external target '\(targetID)' completed" : message)
        case ExitCode.notFound.value:
            return .notFound(message)
        case ExitCode.permissionDenied.value:
            return .permissionDenied(message)
        default:
            return .error(message, exitCode: .raw(Int(result.status)))
        }
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

struct ExternalAdapterPayload: Encodable {
    let targetID: String
    let target: [String: ConfigValue]
    let runtime: ExternalAdapterRuntime
}

struct ExternalAdapterRuntime: Encodable {
    let dryRun: Bool
    let verbose: Bool
    let quiet: Bool
}
