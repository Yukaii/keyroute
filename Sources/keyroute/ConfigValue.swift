import Foundation

enum ConfigValue: Codable, Equatable {
    case string(String)
    case bool(Bool)
    case int(Int)
    case double(Double)
    case array([ConfigValue])
    case object([String: ConfigValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([ConfigValue].self) {
            self = .array(value)
        } else if let value = try? container.decode([String: ConfigValue].self) {
            self = .object(value)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "unsupported config value")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .string(value):
            try container.encode(value)
        case let .bool(value):
            try container.encode(value)
        case let .int(value):
            try container.encode(value)
        case let .double(value):
            try container.encode(value)
        case let .array(value):
            try container.encode(value)
        case let .object(value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }

    var stringValue: String? {
        if case let .string(value) = self { return value }
        return nil
    }

    var boolValue: Bool? {
        if case let .bool(value) = self { return value }
        return nil
    }

    var intValue: Int? {
        if case let .int(value) = self { return value }
        return nil
    }

    var stringArrayValue: [String]? {
        guard case let .array(values) = self else { return nil }
        return values.map(\.stringValue).compactMap { $0 }
    }

    var stringMapValue: [String: String]? {
        guard case let .object(values) = self else { return nil }
        var result: [String: String] = [:]
        for (key, value) in values {
            guard let string = value.stringValue else { return nil }
            result[key] = string
        }
        return result
    }
}

struct DynamicCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init?(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }
}
