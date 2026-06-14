import Foundation
import Yams

public enum OutputFormat: String {
    case text
    case json
    case yaml
}

public func emit<T: Encodable>(_ value: T, format: OutputFormat) throws {
    switch format {
    case .text:
        print(value)
    case .json:
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        print(String(data: try encoder.encode(value), encoding: .utf8) ?? "{}")
    case .yaml:
        print(try YAMLEncoder().encode(value))
    }
}

public struct ListOutput: Codable {
    public let aliases: [String: String]
    public let targets: [String]
    public let profiles: [String]

    public init(aliases: [String: String], targets: [String], profiles: [String]) {
        self.aliases = aliases
        self.targets = targets
        self.profiles = profiles
    }
}

public struct InspectOutput: Codable {
    public let id: String
    public let kind: String
    public let config: TargetConfig?
    public let profile: ProfileConfig?

    public init(id: String, kind: String, config: TargetConfig?, profile: ProfileConfig?) {
        self.id = id
        self.kind = kind
        self.config = config
        self.profile = profile
    }
}
