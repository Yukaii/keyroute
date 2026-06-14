import Foundation

public enum PlatformPaths {
    public static func homeDirectory(environment: [String: String] = ProcessInfo.processInfo.environment) -> String {
        if let home = environment["HOME"], !home.isEmpty {
            return expandedPath(home)
        }
        return FileManager.default.homeDirectoryForCurrentUser.path
    }

    public static func configDirectory(environment: [String: String] = ProcessInfo.processInfo.environment) -> String {
        if let xdgConfigHome = absoluteEnvironmentPath("XDG_CONFIG_HOME", environment: environment) {
            return xdgConfigHome
        }
        return "\(homeDirectory(environment: environment))/.config"
    }

    public static func stateDirectory(environment: [String: String] = ProcessInfo.processInfo.environment) -> String {
        if let xdgStateHome = absoluteEnvironmentPath("XDG_STATE_HOME", environment: environment) {
            return xdgStateHome
        }
        return "\(homeDirectory(environment: environment))/.local/state"
    }

    private static func absoluteEnvironmentPath(_ key: String, environment: [String: String]) -> String? {
        guard let value = environment[key], value.hasPrefix("/") else {
            return nil
        }
        return expandedPath(value)
    }
}
