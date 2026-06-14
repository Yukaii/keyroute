import Foundation

public struct ChromiumAdapter: Adapter {
    public init() {}

    public func activate(targetID: String, target: TargetConfig, context: RuntimeContext) -> AdapterResult {
        guard let browser = target.browser, !browser.isEmpty else {
            return .error("chromium target '\(targetID)' requires 'browser'")
        }
        guard let workspace = target.workspace, !workspace.isEmpty else {
            return .error("chromium target '\(targetID)' requires 'workspace'")
        }
        guard let command = target.command, !command.isEmpty else {
            return .error("chromium target '\(targetID)' requires 'command' for the MVP script-wrapper adapter")
        }

        let args = ["--browser", browser, "--workspace", workspace]
        if context.dryRun {
            return .success("dry-run: would execute \(command) \(args.joined(separator: " "))")
        }

        let status = CommandRunner().run(executable: command, arguments: args, quiet: context.quiet)
        if status == 0 {
            return .success("chromium target '\(targetID)' focused workspace '\(workspace)'")
        }
        return .error("chromium target '\(targetID)' command exited with status \(status)")
    }
}
