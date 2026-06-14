import Foundation

struct TmuxAdapter: Adapter {
    func activate(targetID: String, target: TargetConfig, context: RuntimeContext) -> AdapterResult {
        guard let session = target.session, !session.isEmpty else {
            return .error("tmux target '\(targetID)' requires 'session'")
        }

        let runner = CommandRunner()
        if context.dryRun {
            var steps = ["would check tmux session '\(session)'"]
            if target.create == true {
                steps.append("would create missing session")
            }
            if let app = target.app {
                steps.append("would activate app \(app)")
            }
            steps.append("would switch attached client to '\(session)'")
            return .success("dry-run: \(steps.joined(separator: "; "))")
        }

        let hasSession = runner.run(executable: "/usr/bin/env", arguments: ["tmux", "has-session", "-t", session], quiet: true)
        if hasSession != 0 {
            guard target.create == true else {
                return .notFound("tmux session '\(session)' not found and create is false")
            }
            var args = ["tmux", "new-session", "-d", "-s", session]
            if let cwd = target.cwd {
                args.append(contentsOf: ["-c", expandedPath(cwd)])
            }
            let created = runner.run(executable: "/usr/bin/env", arguments: args, quiet: context.quiet)
            guard created == 0 else {
                return .error("failed to create tmux session '\(session)'")
            }
        }

        if let bundleID = target.app {
            activateApp(bundleID: bundleID)
        }

        let switched = runner.run(executable: "/usr/bin/env", arguments: ["tmux", "switch-client", "-t", session], quiet: context.quiet)
        if switched == 0 {
            return .success("tmux session '\(session)' focused")
        }
        return .error("tmux session '\(session)' exists, but no attached client could be switched")
    }
}
