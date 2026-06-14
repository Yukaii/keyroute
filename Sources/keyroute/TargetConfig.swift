import Foundation

struct TargetConfig: Codable {
    let fields: [String: ConfigValue]

    init(fields: [String: ConfigValue]) {
        self.fields = fields
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        var fields: [String: ConfigValue] = [:]
        for key in container.allKeys {
            fields[key.stringValue] = try container.decode(ConfigValue.self, forKey: key)
        }
        self.fields = fields
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DynamicCodingKey.self)
        for (key, value) in fields {
            guard let codingKey = DynamicCodingKey(stringValue: key) else { continue }
            try container.encode(value, forKey: codingKey)
        }
    }

    var adapter: String {
        string("adapter") ?? ""
    }

    var app: String? { string("app") }
    var session: String? { string("session") }
    var cwd: String? { string("cwd") }
    var create: Bool? { bool("create") }
    var browser: String? { string("browser") }
    var workspace: String? { string("workspace") }
    var command: String? { string("command") }
    var run: String? { string("run") }
    var args: [String]? { stringArray("args") }
    var env: [String: String]? { stringMap("env") }
    var title: String? { string("title") }
    var titleContains: String? { string("titleContains") }
    var titleRegex: String? { string("titleRegex") }
    var windowIndex: Int? { int("windowIndex") }

    var hasWindowMatchRule: Bool {
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
