import Foundation

public struct TargetConfig: Codable {
    public let fields: [String: ConfigValue]

    public init(fields: [String: ConfigValue]) {
        self.fields = fields
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        var fields: [String: ConfigValue] = [:]
        for key in container.allKeys {
            fields[key.stringValue] = try container.decode(ConfigValue.self, forKey: key)
        }
        self.fields = fields
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DynamicCodingKey.self)
        for (key, value) in fields {
            guard let codingKey = DynamicCodingKey(stringValue: key) else { continue }
            try container.encode(value, forKey: codingKey)
        }
    }

    public var adapter: String {
        string("adapter") ?? ""
    }

    public var app: String? { string("app") }
    public var session: String? { string("session") }
    public var cwd: String? { string("cwd") }
    public var create: Bool? { bool("create") }
    public var browser: String? { string("browser") }
    public var workspace: String? { string("workspace") }
    public var profile: String? { string("profile") }
    public var lang: String? { string("lang") }
    public var command: String? { string("command") }
    public var run: String? { string("run") }
    public var args: [String]? { stringArray("args") }
    public var env: [String: String]? { stringMap("env") }
    public var title: String? { string("title") }
    public var titleContains: String? { string("titleContains") }
    public var titleRegex: String? { string("titleRegex") }
    public var windowIndex: Int? { int("windowIndex") }

    public var hasWindowMatchRule: Bool {
        title != nil || titleContains != nil || titleRegex != nil || windowIndex != nil
    }

    private func string(_ key: String) -> String? {
        fields[key]?.stringValue
    }

    private func bool(_ key: String) -> Bool? {
        fields[key]?.boolValue
    }

    private func int(_ key: String) -> Int? {
        fields[key]?.intValue
    }

    private func stringArray(_ key: String) -> [String]? {
        fields[key]?.stringArrayValue
    }

    private func stringMap(_ key: String) -> [String: String]? {
        fields[key]?.stringMapValue
    }
}
