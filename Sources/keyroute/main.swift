import ApplicationServices
import Foundation

struct GlobalOptions {
    var format: OutputFormat = .text
    var dryRun = false
    var verbose = false
    var quiet = false
}

enum KeyrouteCLI {
    static func main() {
        do {
            var args = Array(CommandLine.arguments.dropFirst())
            let options = try parseGlobalOptions(args: &args)
            guard let command = args.first else {
                printUsage()
                Foundation.exit(ExitCode.general.value)
            }
            args.removeFirst()

            switch command {
            case "go":
                try go(args: args, options: options)
            case "profile":
                try profile(args: args, options: options)
            case "list":
                try list(options: options)
            case "inspect":
                try inspect(args: args, options: options)
            case "doctor":
                try doctor(options: options)
            case "config":
                try config(args: args)
            case "help", "--help", "-h":
                printUsage()
            default:
                throw KeyrouteError.general("unknown command '\(command)'")
            }
        } catch {
            fail(error)
        }
    }

    private static func parseGlobalOptions(args: inout [String]) throws -> GlobalOptions {
        var options = GlobalOptions()
        var remaining: [String] = []
        var iterator = args.makeIterator()

        while let arg = iterator.next() {
            switch arg {
            case "--format":
                guard let value = iterator.next(), let format = OutputFormat(rawValue: value) else {
                    throw KeyrouteError.general("--format requires text, json, or yaml")
                }
                options.format = format
            case "--dry-run":
                options.dryRun = true
            case "--verbose", "-v":
                options.verbose = true
            case "--quiet", "-q":
                options.quiet = true
            default:
                remaining.append(arg)
            }
        }

        args = remaining
        return options
    }

    private static func go(args: [String], options: GlobalOptions) throws {
        guard let name = args.first else {
            throw KeyrouteError.general("usage: keyroute go <target-or-alias>")
        }
        let loaded = try ConfigLoader.load()
        let (targetID, target) = try loaded.resolveTarget(name)
        let result = activateTarget(id: targetID, target: target, options: options)
        finish(result)
    }

    private static func profile(args: [String], options: GlobalOptions) throws {
        guard let first = args.first else {
            throw KeyrouteError.general("usage: keyroute profile <name>|list")
        }
        let loaded = try ConfigLoader.load()

        if first == "list" {
            for id in loaded.config.profileMap.keys.sorted() {
                print(id)
            }
            return
        }

        var focusOverride: String?
        var index = 1
        while index < args.count {
            if args[index] == "--focus" {
                guard args.indices.contains(index + 1) else {
                    throw KeyrouteError.general("--focus requires a target id or default")
                }
                focusOverride = args[index + 1]
                index += 2
            } else {
                throw KeyrouteError.general("unknown profile argument '\(args[index])'")
            }
        }

        let (profileID, profile) = try loaded.resolveProfile(first)
        let targetIDs = profile.targets ?? []
        for targetID in targetIDs {
            guard let target = loaded.config.targetMap[targetID] else {
                throw KeyrouteError.config("profile '\(profileID)' references unknown target '\(targetID)'")
            }
            let result = activateTarget(id: targetID, target: target, options: options)
            guard result.exitCode == .success else { finish(result) }
        }

        let defaultID = profile.default
        let focusID = focusOverride == "default" ? defaultID : (focusOverride ?? defaultID)
        if let focusID {
            guard let target = loaded.config.targetMap[focusID] else {
                throw KeyrouteError.config("profile '\(profileID)' focus references unknown target '\(focusID)'")
            }
            let result = activateTarget(id: focusID, target: target, options: options)
            guard result.exitCode == .success else { finish(result) }
        }

        if !options.dryRun {
            try StateStore.save(activeProfile: profileID)
        }
        if !options.quiet {
            print("profile '\(profileID)' activated")
        }
    }

    private static func list(options: GlobalOptions) throws {
        let loaded = try ConfigLoader.load()
        let output = ListOutput(
            aliases: loaded.config.aliasMap,
            targets: loaded.config.targetMap.keys.sorted(),
            profiles: loaded.config.profileMap.keys.sorted()
        )

        switch options.format {
        case .text:
            print("Aliases:")
            for (alias, reference) in output.aliases.sorted(by: { $0.key < $1.key }) {
                print("  \(alias) -> \(reference)")
            }
            print("Targets:")
            output.targets.forEach { print("  \($0)") }
            print("Profiles:")
            output.profiles.forEach { print("  \($0)") }
        case .json, .yaml:
            try emit(output, format: options.format)
        }
    }

    private static func inspect(args: [String], options: GlobalOptions) throws {
        guard let name = args.first else {
            throw KeyrouteError.general("usage: keyroute inspect <target-or-profile-or-alias>")
        }
        let loaded = try ConfigLoader.load()
        switch try loaded.resolve(name) {
        case let .target(id, config):
            if options.format == .text {
                print("Target: \(id)")
                print("Adapter: \(config.adapter)")
                try emit(InspectOutput(id: id, kind: "target", config: config, profile: nil), format: .yaml)
            } else {
                try emit(InspectOutput(id: id, kind: "target", config: config, profile: nil), format: options.format)
            }
        case let .profile(id, profile):
            if options.format == .text {
                print("Profile: \(id)")
                try emit(InspectOutput(id: id, kind: "profile", config: nil, profile: profile), format: .yaml)
            } else {
                try emit(InspectOutput(id: id, kind: "profile", config: nil, profile: profile), format: options.format)
            }
        }
    }

    private static func doctor(options: GlobalOptions) throws {
        let loaded = try ConfigLoader.load()
        if !options.quiet {
            print("config: ok (\(loaded.path))")
            print("targets: \(loaded.config.targetMap.count)")
            print("profiles: \(loaded.config.profileMap.count)")
            let tmuxStatus = CommandRunner().run(executable: "/usr/bin/env", arguments: ["tmux", "-V"], quiet: true)
            print("tmux: \(tmuxStatus == 0 ? "available" : "not found")")
            print("accessibility: \(AXIsProcessTrusted() ? "granted" : "not granted")")
        }
    }

    private static func config(args: [String]) throws {
        guard args.first == "path" else {
            throw KeyrouteError.general("usage: keyroute config path")
        }
        print(ConfigLoader.defaultPath())
    }

    private static func activateTarget(id: String, target: TargetConfig, options: GlobalOptions) -> AdapterResult {
        guard let adapter = AdapterRegistry().adapter(named: target.adapter) else {
            return .error("unknown adapter '\(target.adapter)'", exitCode: .config)
        }
        let context = RuntimeContext(
            dryRun: options.dryRun,
            verbose: options.verbose,
            quiet: options.quiet,
            environment: ProcessInfo.processInfo.environment
        )
        let result = adapter.activate(targetID: id, target: target, context: context)
        if options.verbose, !options.quiet {
            print("[\(result.status.rawValue)] \(result.message)")
        }
        return result
    }

    private static func finish(_ result: AdapterResult) -> Never {
        if result.exitCode == .success {
            if !result.message.isEmpty {
                print(result.message)
            }
        } else {
            fputs("keyroute: \(result.message)\n", stderr)
        }
        Foundation.exit(result.exitCode.value)
    }

    private static func printUsage() {
        print("""
        keyroute - deterministic session and window router

        Usage:
          keyroute go <target-or-alias> [--dry-run]
          keyroute profile <name> [--focus <target-id|default>] [--dry-run]
          keyroute profile list
          keyroute list [--format text|json|yaml]
          keyroute inspect <name> [--format text|json|yaml]
          keyroute doctor
          keyroute config path
        """)
    }
}

KeyrouteCLI.main()
