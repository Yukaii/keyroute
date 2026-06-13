import AppKit
import ApplicationServices
import Foundation

enum AdapterStatus: String {
    case success
    case notFound = "not-found"
    case permissionDenied = "permission-denied"
    case error
}

struct AdapterResult {
    let status: AdapterStatus
    let message: String
    let exitCode: ExitCode

    static func success(_ message: String) -> AdapterResult {
        AdapterResult(status: .success, message: message, exitCode: .success)
    }

    static func notFound(_ message: String) -> AdapterResult {
        AdapterResult(status: .notFound, message: message, exitCode: .notFound)
    }

    static func permissionDenied(_ message: String) -> AdapterResult {
        AdapterResult(status: .permissionDenied, message: message, exitCode: .permissionDenied)
    }

    static func error(_ message: String, exitCode: ExitCode = .adapterError) -> AdapterResult {
        AdapterResult(status: .error, message: message, exitCode: exitCode)
    }
}

struct RuntimeContext {
    let dryRun: Bool
    let verbose: Bool
    let quiet: Bool
    let environment: [String: String]
}

protocol Adapter {
    func activate(targetID: String, target: TargetConfig, context: RuntimeContext) -> AdapterResult
}

struct AdapterRegistry {
    func adapter(named name: String) -> Adapter? {
        switch name {
        case "command":
            CommandAdapter()
        case "chromium":
            ChromiumAdapter()
        case "tmux":
            TmuxAdapter()
        case "macos-window":
            MacOSWindowAdapter()
        default:
            nil
        }
    }
}

struct CommandRunner {
    func run(
        executable: String,
        arguments: [String] = [],
        cwd: String? = nil,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        quiet: Bool = false
    ) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: expandedPath(executable))
        process.arguments = arguments
        process.environment = environment
        if let cwd {
            process.currentDirectoryURL = URL(fileURLWithPath: expandedPath(cwd))
        }

        if quiet {
            process.standardOutput = Pipe()
            process.standardError = Pipe()
        }

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus
        } catch {
            fputs("\(error.localizedDescription)\n", stderr)
            return 127
        }
    }
}

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

struct ChromiumAdapter: Adapter {
    func activate(targetID: String, target: TargetConfig, context: RuntimeContext) -> AdapterResult {
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

struct MacOSWindowAdapter: Adapter {
    func activate(targetID: String, target: TargetConfig, context: RuntimeContext) -> AdapterResult {
        guard let bundleID = target.app, !bundleID.isEmpty else {
            return .error("macos-window target '\(targetID)' requires 'app'")
        }
        guard target.hasWindowMatchRule else {
            return .error("macos-window target '\(targetID)' requires title, titleContains, titleRegex, or windowIndex")
        }

        if context.dryRun {
            return .success("dry-run: would raise matching window for app \(bundleID)")
        }

        guard AXIsProcessTrusted() else {
            return .permissionDenied("Accessibility permission is required. Grant Keyroute access in System Settings > Privacy & Security > Accessibility.")
        }

        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first else {
            return .notFound("app '\(bundleID)' is not running")
        }

        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        var windowsValue: CFTypeRef?
        let copyResult = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsValue)
        guard copyResult == .success, let windows = windowsValue as? [AXUIElement], !windows.isEmpty else {
            return .notFound("no accessible windows found for app '\(bundleID)'")
        }

        guard let window = matchingWindow(in: windows, target: target) else {
            return .notFound("no window matched target '\(targetID)'")
        }

        AXUIElementPerformAction(window, kAXRaiseAction as CFString)
        app.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
        return .success("window target '\(targetID)' focused")
    }

    private func matchingWindow(in windows: [AXUIElement], target: TargetConfig) -> AXUIElement? {
        if let index = target.windowIndex {
            let arrayIndex = index - 1
            guard windows.indices.contains(arrayIndex) else { return nil }
            return windows[arrayIndex]
        }

        return windows.first { window in
            let title = windowTitle(window)
            if let exact = target.title, title == exact {
                return true
            }
            if let contains = target.titleContains, title.localizedCaseInsensitiveContains(contains) {
                return true
            }
            if let pattern = target.titleRegex {
                return title.range(of: pattern, options: .regularExpression) != nil
            }
            return false
        }
    }

    private func windowTitle(_ window: AXUIElement) -> String {
        var titleValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleValue) == .success else {
            return ""
        }
        return titleValue as? String ?? ""
    }
}

@discardableResult
func activateApp(bundleID: String) -> Bool {
    guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first else {
        return false
    }
    return app.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
}

func expandedPath(_ path: String) -> String {
    NSString(string: path).expandingTildeInPath
}
