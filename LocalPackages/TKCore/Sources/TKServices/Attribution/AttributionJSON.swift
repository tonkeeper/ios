import Foundation

public enum AttributionJSON: Equatable, Sendable {
    case string(String)
    case bool(Bool)
    case number(Double)
    case object([String: AttributionJSON])
    case array([AttributionJSON])
    case null
}

extension AttributionJSON: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
            return
        }
        if let value = try? container.decode(Bool.self) {
            self = .bool(value)
            return
        }
        if let value = try? container.decode(Double.self) {
            self = .number(value)
            return
        }
        if let value = try? container.decode(String.self) {
            self = .string(value)
            return
        }
        if let value = try? container.decode([String: AttributionJSON].self) {
            self = .object(value)
            return
        }
        if let value = try? container.decode([AttributionJSON].self) {
            self = .array(value)
            return
        }
        throw DecodingError.dataCorruptedError(
            in: container,
            debugDescription: "Unsupported attribution JSON value"
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null:
            try container.encodeNil()
        case let .string(value):
            try container.encode(value)
        case let .bool(value):
            try container.encode(value)
        case let .number(value):
            try container.encode(value)
        case let .object(value):
            try container.encode(value)
        case let .array(value):
            try container.encode(value)
        }
    }
}

extension AttributionJSON {
    var stringValue: String? {
        if case let .string(value) = self {
            return value
        }
        return nil
    }

    var boolValue: Bool? {
        switch self {
        case let .bool(value):
            return value
        case let .number(value):
            if value == 0 {
                return false
            }
            if value == 1 {
                return true
            }
            return nil
        default:
            return nil
        }
    }

    var objectValue: [String: AttributionJSON]? {
        if case let .object(value) = self {
            return value
        }
        return nil
    }
}
