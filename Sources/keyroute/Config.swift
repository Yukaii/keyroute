import Foundation
import Yams

struct KeyrouteConfig: Codable {
    var aliases: [String: String]?
    var targets: [String: TargetConfig]?
    var profiles: [String: ProfileConfig]?

    var aliasMap: [String: String] { aliases ?? [:] }
    var targetMap: [String: TargetConfig] { targets ?? [:] }
    var profileMap: [String: ProfileConfig] { profiles ?? [:] }
}

struct ProfileConfig: Codable {
    let targets: [String]?
    let `default`: String?
    let mode: String?
    let keymaps: [String: [String: String]]?
}

enum ConfigLoader {
    static func defaultPath() -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/.config/keyroute/config.yaml"
    }

    static func load(path: String = defaultPath()) throws -> LoadedConfig {
        try validateConfigPath(path)
        guard FileManager.default.fileExists(atPath: path) else {
            throw KeyrouteError.config("missing config file: \(path)")
        }

        do {
            let yaml = try String(contentsOfFile: path, encoding: .utf8)
            let config = try YAMLDecoder().decode(KeyrouteConfig.self, from: yaml)
            let loaded = LoadedConfig(path: path, config: config)
            try loaded.validate()
            return loaded
        } catch let error as KeyrouteError {
            throw error
        } catch {
            throw KeyrouteError.config("invalid config at \(path): \(error)")
        }
    }

    private static func validateConfigPath(_ path: String) throws {
        let defaultPath = defaultPath()
        guard expandedPath(path) == expandedPath(defaultPath) else {
            throw KeyrouteError.config("refusing to load config outside \(defaultPath)")
        }

        var isDirectory: ObjCBool = false
        let directory = URL(fileURLWithPath: expandedPath(path)).deletingLastPathComponent().path
        guard FileManager.default.fileExists(atPath: directory, isDirectory: &isDirectory), isDirectory.boolValue else {
            return
        }

        let attrs = try FileManager.default.attributesOfItem(atPath: directory)
        if let permissions = attrs[.posixPermissions] as? NSNumber, permissions.intValue & 0o002 != 0 {
            throw KeyrouteError.config("refusing to load config from world-writable directory: \(directory)")
        }
    }
}

struct LoadedConfig {
    let path: String
    let config: KeyrouteConfig

    func resolve(_ name: String) throws -> ResolvedReference {
        if let targetID = name.removingPrefix("target.") {
            guard let target = config.targetMap[targetID] else {
                throw unknownTarget(targetID)
            }
            return .target(id: targetID, config: target)
        }

        if let profileID = name.removingPrefix("profile.") {
            guard let profile = config.profileMap[profileID] else {
                throw unknownProfile(profileID)
            }
            return .profile(id: profileID, config: profile)
        }

        if let target = config.targetMap[name] {
            return .target(id: name, config: target)
        }

        if let profile = config.profileMap[name] {
            return .profile(id: name, config: profile)
        }

        if let alias = config.aliasMap[name] {
            return try resolvePrefixedAlias(name: name, alias: alias)
        }

        throw KeyrouteError.notFound("unknown target, profile, or alias '\(name)'. Valid names: \(validNames().joined(separator: ", "))")
    }

    func resolveTarget(_ name: String) throws -> (String, TargetConfig) {
        switch try resolve(name) {
        case let .target(id, config):
            return (id, config)
        case let .profile(id, _):
            throw KeyrouteError.config("'\(name)' resolves to profile '\(id)', not a target")
        }
    }

    func resolveProfile(_ name: String) throws -> (String, ProfileConfig) {
        switch try resolve(name) {
        case let .profile(id, config):
            return (id, config)
        case let .target(id, _):
            throw KeyrouteError.config("'\(name)' resolves to target '\(id)', not a profile")
        }
    }

    func validate() throws {
        let targetNames = Set(config.targetMap.keys)
        let profileNames = Set(config.profileMap.keys)
        let aliasNames = Set(config.aliasMap.keys)
        let duplicates = targetNames.intersection(profileNames)
            .union(targetNames.intersection(aliasNames))
            .union(profileNames.intersection(aliasNames))
        guard duplicates.isEmpty else {
            throw KeyrouteError.config("names cannot be reused across aliases, targets, and profiles: \(duplicates.sorted().joined(separator: ", "))")
        }

        for (alias, reference) in config.aliasMap {
            guard reference.hasPrefix("target.") || reference.hasPrefix("profile.") else {
                throw KeyrouteError.config("alias '\(alias)' must reference target.<id> or profile.<id>")
            }
            _ = try resolvePrefixedAlias(name: alias, alias: reference)
        }

        for (id, target) in config.targetMap {
            try validateTarget(id: id, target: target)
        }

        for (id, profile) in config.profileMap {
            try validateProfile(id: id, profile: profile)
        }
    }

    func validNames() -> [String] {
        (Array(config.targetMap.keys) + Array(config.profileMap.keys) + Array(config.aliasMap.keys)).sorted()
    }

    private func resolvePrefixedAlias(name: String, alias: String) throws -> ResolvedReference {
        if let targetID = alias.removingPrefix("target.") {
            guard let target = config.targetMap[targetID] else {
                throw KeyrouteError.config("alias '\(name)' references unknown target '\(targetID)'")
            }
            return .target(id: targetID, config: target)
        }

        if let profileID = alias.removingPrefix("profile.") {
            guard let profile = config.profileMap[profileID] else {
                throw KeyrouteError.config("alias '\(name)' references unknown profile '\(profileID)'")
            }
            return .profile(id: profileID, config: profile)
        }

        throw KeyrouteError.config("alias '\(name)' must reference target.<id> or profile.<id>")
    }

    private func validateTarget(id: String, target: TargetConfig) throws {
        switch target.adapter {
        case "command":
            guard target.run != nil || target.command != nil else {
                throw KeyrouteError.config("target '\(id)' command adapter requires 'run' or 'command'")
            }
        case "external":
            guard target.run != nil || target.command != nil else {
                throw KeyrouteError.config("target '\(id)' external adapter requires 'run' or 'command'")
            }
        case "chromium":
            guard target.browser != nil else { throw KeyrouteError.config("target '\(id)' chromium adapter requires 'browser'") }
            guard target.workspace != nil else { throw KeyrouteError.config("target '\(id)' chromium adapter requires 'workspace'") }
        case "tmux":
            guard target.session != nil else { throw KeyrouteError.config("target '\(id)' tmux adapter requires 'session'") }
        case "macos-window":
            guard target.app != nil else { throw KeyrouteError.config("target '\(id)' macos-window adapter requires 'app'") }
            guard target.hasWindowMatchRule else {
                throw KeyrouteError.config("target '\(id)' macos-window adapter requires a window match rule")
            }
        default:
            throw KeyrouteError.config("target '\(id)' uses unknown adapter '\(target.adapter)'")
        }
    }

    private func validateProfile(id: String, profile: ProfileConfig) throws {
        let targetIDs = profile.targets ?? []
        for targetID in targetIDs {
            guard config.targetMap[targetID] != nil else {
                throw KeyrouteError.config("profile '\(id)' references unknown target '\(targetID)'")
            }
        }

        if let defaultID = profile.default {
            guard config.targetMap[defaultID] != nil else {
                throw KeyrouteError.config("profile '\(id)' default references unknown target '\(defaultID)'")
            }
        }

        if let mode = profile.mode, mode != "sequential" {
            throw KeyrouteError.config("profile '\(id)' uses unsupported mode '\(mode)'")
        }

        for (namespace, keymap) in profile.keymaps ?? [:] {
            for (key, targetID) in keymap {
                guard config.targetMap[targetID] != nil else {
                    throw KeyrouteError.config("profile '\(id)' keymap \(namespace).\(key) references unknown target '\(targetID)'")
                }
            }
        }
    }

    private func unknownTarget(_ name: String) -> KeyrouteError {
        .notFound("unknown target '\(name)'. Valid targets: \(config.targetMap.keys.sorted().joined(separator: ", "))")
    }

    private func unknownProfile(_ name: String) -> KeyrouteError {
        .notFound("unknown profile '\(name)'. Valid profiles: \(config.profileMap.keys.sorted().joined(separator: ", "))")
    }
}

enum ResolvedReference {
    case target(id: String, config: TargetConfig)
    case profile(id: String, config: ProfileConfig)
}

extension String {
    func removingPrefix(_ prefix: String) -> String? {
        guard hasPrefix(prefix) else { return nil }
        return String(dropFirst(prefix.count))
    }
}
