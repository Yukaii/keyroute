import Foundation

public struct ChromiumAdapter: Adapter {
    public static let defaultCommand = "~/.config/keyroute/adapters/switch-chromium"

    public init() {}

    public func activate(targetID: String, target: TargetConfig, context: RuntimeContext) -> AdapterResult {
        guard let browser = target.browser, !browser.isEmpty else {
            return .error("chromium target '\(targetID)' requires 'browser'")
        }

        let hasWorkspace = target.workspace != nil && !target.workspace!.isEmpty
        let hasProfile = target.profile != nil && !target.profile!.isEmpty

        guard hasWorkspace || hasProfile else {
            return .error("chromium target '\(targetID)' requires either 'workspace' or 'profile'")
        }

        guard !(hasWorkspace && hasProfile) else {
            return .error("chromium target '\(targetID)' cannot specify both 'workspace' and 'profile'")
        }

        let command = target.command.map { $0.isEmpty ? ChromiumAdapter.defaultCommand : $0 }
            ?? ChromiumAdapter.defaultCommand

        var args = ["--browser", browser]
        if hasWorkspace {
            args += ["--workspace", target.workspace!]
        } else {
            args += ["--profile", target.profile!]
        }

        let lang = target.lang.map { $0.isEmpty ? "en" : $0 } ?? "en"
        switch lang {
        case "jp":
            args.append("--jp")
        case "zh-tw", "zh_tw", "zh-TW":
            args.append("--zh-tw")
        case "zh-cn", "zh_cn", "zh-CN":
            args.append("--zh-cn")
        case "en":
            args.append("--en")
        default:
            return .error("chromium target '\(targetID)' uses unsupported 'lang' '\(lang)'")
        }

        if context.dryRun {
            return .success("dry-run: would execute \(command) \(args.joined(separator: " "))")
        }

        let status = CommandRunner().run(executable: command, arguments: args, quiet: context.quiet)
        if status == 0 {
            let kind = hasWorkspace ? "workspace '\(target.workspace!)'" : "profile '\(target.profile!)'"
            return .success("chromium target '\(targetID)' focused \(kind)")
        }
        return .error("chromium target '\(targetID)' command exited with status \(status)")
    }
}
