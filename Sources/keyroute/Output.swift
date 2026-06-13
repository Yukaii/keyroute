import Foundation
import Yams

enum OutputFormat: String {
    case text
    case json
    case yaml
}

func emit<T: Encodable>(_ value: T, format: OutputFormat) throws {
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

struct ListOutput: Codable {
    let aliases: [String: String]
    let targets: [String]
    let profiles: [String]
}

struct InspectOutput: Codable {
    let id: String
    let kind: String
    let config: TargetConfig?
    let profile: ProfileConfig?
}
