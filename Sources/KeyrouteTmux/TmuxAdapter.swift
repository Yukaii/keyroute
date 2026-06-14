#if os(macOS)
import AppKit
#endif
import Foundation
import KeyrouteCore

public struct TmuxAdapter: Adapter {
    public init() {}

    public func activate(targetID: String, target: TargetConfig, context: RuntimeContext) -> AdapterResult {
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
                if supportsAppActivation() {
                    steps.append("would activate app \(app)")
                } else {
                    steps.append("would skip app activation for \(app) on \(currentPlatformName())")
                }
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

        if let bundleID = target.app, supportsAppActivation() {
            activateApp(bundleID: bundleID)
        }

        let switched = runner.run(executable: "/usr/bin/env", arguments: ["tmux", "switch-client", "-t", session], quiet: context.quiet)
        if switched == 0 {
            return .success("tmux session '\(session)' focused")
        }
        return .error("tmux session '\(session)' exists, but no attached client could be switched")
    }
}

@discardableResult
private func activateApp(bundleID: String) -> Bool {
    #if os(macOS)
    guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first else {
        return false
    }
    return app.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
    #else
    return false
    #endif
}

private func supportsAppActivation() -> Bool {
    #if os(macOS)
    return true
    #else
    return false
    #endif
}
