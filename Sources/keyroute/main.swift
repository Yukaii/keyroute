import Foundation
import KeyrouteCore

#if os(macOS)
import KeyrouteMacOS
#endif

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
            case "key":
                try key(args: args, options: options)
            case "list":
                try list(options: options)
            case "inspect":
                try inspect(args: args, options: options)
            case "doctor":
                try doctor(options: options)
            case "config":
                try config(args: args)
            case "example":
                try example(args: args)
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
        finish(result, quiet: options.quiet)
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

        if first == "current" {
            let state = try StateStore.load()
            if let activeProfile = state.activeProfile {
                print(activeProfile)
            } else {
                throw KeyrouteError.activeProfileMissing("no active profile. Run 'keyroute profile set <name>' or pass --profile <name>'.")
            }
            return
        }

        if first == "set" {
            guard args.indices.contains(1) else {
                throw KeyrouteError.general("usage: keyroute profile set <name>")
            }
            let profileID = args[1]
            _ = try loaded.resolveProfile(profileID)
            if !options.dryRun {
                try StateStore.save(activeProfile: profileID)
            }
            if !options.quiet {
                print(options.dryRun ? "dry-run: active profile would be set to '\(profileID)'" : "active profile set to '\(profileID)'")
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
            guard result.exitCode == .success else { finish(result, quiet: options.quiet) }
        }

        let defaultID = profile.default
        let focusID = focusOverride == "default" ? defaultID : (focusOverride ?? defaultID)
        if let focusID {
            guard let target = loaded.config.targetMap[focusID] else {
                throw KeyrouteError.config("profile '\(profileID)' focus references unknown target '\(focusID)'")
            }
            let result = activateTarget(id: focusID, target: target, options: options)
            guard result.exitCode == .success else { finish(result, quiet: options.quiet) }
        }

        if !options.dryRun {
            try StateStore.save(activeProfile: profileID)
        }
        if !options.quiet {
            if options.dryRun {
                print("dry-run: profile '\(profileID)' activation resolved")
            } else {
                print("profile '\(profileID)' activated")
            }
        }
    }

    private static func key(args: [String], options: GlobalOptions) throws {
        var args = args
        var profileOverride: String?

        if args.first == "--profile" {
            guard args.indices.contains(1) else {
                throw KeyrouteError.general("--profile requires a profile name")
            }
            profileOverride = args[1]
            args.removeFirst(2)
        }

        guard args.count == 2 else {
            throw KeyrouteError.general("usage: keyroute key [--profile <profile>] <namespace> <key>")
        }

        let namespace = args[0]
        let key = args[1]
        let loaded = try ConfigLoader.load()
        let profileID: String
        let profile: ProfileConfig

        if let profileOverride {
            (profileID, profile) = try loaded.resolveProfile(profileOverride)
        } else {
            let state = try StateStore.load()
            guard let activeProfile = state.activeProfile else {
                throw KeyrouteError.activeProfileMissing("no active profile. Run 'keyroute profile set <name>' or pass --profile <name>'.")
            }
            (profileID, profile) = try loaded.resolveProfile(activeProfile)
        }

        guard let namespaceMap = profile.keymaps?[namespace] else {
            throw KeyrouteError.notFound("profile '\(profileID)' has no keymap namespace '\(namespace)'")
        }

        guard let targetID = namespaceMap[key] else {
            let validKeys = namespaceMap.keys.sorted().joined(separator: ", ")
            throw KeyrouteError.notFound("profile '\(profileID)' keymap '\(namespace)' has no key '\(key)'. Valid keys: \(validKeys)")
        }

        let (resolvedID, target) = try loaded.resolveTarget(targetID)
        let result = activateTarget(id: resolvedID, target: target, options: options)
        finish(result, quiet: options.quiet)
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
            print("platform: \(currentPlatformName())")
            print("targets: \(loaded.config.targetMap.count)")
            print("profiles: \(loaded.config.profileMap.count)")
            let tmuxStatus = CommandRunner().run(executable: "/usr/bin/env", arguments: ["tmux", "-V"], quiet: true)
            print("tmux: \(tmuxStatus == 0 ? "available" : "not found")")
            #if os(macOS)
            print("accessibility: \(macOSAccessibilityStatus())")
            #else
            print("accessibility: unsupported")
            #endif
        }
    }

    private static func config(args: [String]) throws {
        guard args.first == "path" else {
            throw KeyrouteError.general("usage: keyroute config path")
        }
        print(ConfigLoader.defaultPath())
    }

    private static func example(args: [String]) throws {
        guard let first = args.first else {
            throw KeyrouteError.general("usage: keyroute example list|show <name>")
        }

        switch first {
        case "list":
            for item in EmbeddedExamples.all.sorted(by: { $0.name < $1.name }) {
                print("\(item.name)\t\(item.description)")
            }
        case "show", "cat":
            guard args.indices.contains(1) else {
                throw KeyrouteError.general("usage: keyroute example show <name>")
            }
            let name = args[1]
            guard let item = EmbeddedExamples.named(name) else {
                throw KeyrouteError.notFound("unknown example '\(name)'. Valid examples: \(EmbeddedExamples.names.joined(separator: ", "))")
            }
            print(item.content)
        default:
            throw KeyrouteError.general("usage: keyroute example list|show <name>")
        }
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

    private static func finish(_ result: AdapterResult, quiet: Bool = false) -> Never {
        if result.exitCode == .success {
            if !quiet, !result.message.isEmpty {
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
          keyroute profile current
          keyroute profile set <name>
          keyroute key [--profile <profile>] <namespace> <key>
          keyroute list [--format text|json|yaml]
          keyroute inspect <name> [--format text|json|yaml]
          keyroute doctor
          keyroute config path
          keyroute example list
          keyroute example show <name>
        """)
    }
}

KeyrouteCLI.main()
