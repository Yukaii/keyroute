import Foundation

struct CommandAdapter: Adapter {
    func activate(targetID: String, target: TargetConfig, context: RuntimeContext) -> AdapterResult {
        guard let command = target.run ?? target.command, !command.isEmpty else {
            return .error("command adapter target '\(targetID)' requires 'run' or 'command'")
        }

        let env = context.environment.merging(target.env ?? [:]) { _, new in new }
        if context.dryRun {
            return .success("dry-run: would execute \(command) \((target.args ?? []).joined(separator: " "))")
        }

        let status = CommandRunner().run(
            executable: command,
            arguments: target.args ?? [],
            cwd: target.cwd,
            environment: env,
            quiet: context.quiet
        )

        if status == 0 {
            return .success("command target '\(targetID)' completed")
        }
        return .error("command target '\(targetID)' exited with status \(status)", exitCode: .raw(Int(status)))
    }
}
