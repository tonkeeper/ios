import Foundation

/// A JSON tree that stays `Sendable` and `Equatable`, used for frame payloads whose shape
/// depends on the frame and the event.
public indirect enum MoonPayJSONValue: Codable, Equatable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case null
    case array([MoonPayJSONValue])
    case object([String: MoonPayJSONValue])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let number = try? container.decode(Double.self) {
            self = .number(number)
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let array = try? container.decode([MoonPayJSONValue].self) {
            self = .array(array)
        } else if let object = try? container.decode([String: MoonPayJSONValue].self) {
            self = .object(object)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .string(string): try container.encode(string)
        case let .number(number): try container.encode(number)
        case let .bool(bool): try container.encode(bool)
        case .null: try container.encodeNil()
        case let .array(array): try container.encode(array)
        case let .object(object): try container.encode(object)
        }
    }
}

public extension MoonPayJSONValue {
    subscript(key: String) -> MoonPayJSONValue? {
        guard case let .object(object) = self else { return nil }
        return object[key]
    }

    var stringValue: String? {
        guard case let .string(string) = self else { return nil }
        return string
    }

    var numberValue: Double? {
        guard case let .number(number) = self else { return nil }
        return number
    }

    var boolValue: Bool? {
        guard case let .bool(bool) = self else { return nil }
        return bool
    }

    var arrayValue: [MoonPayJSONValue]? {
        guard case let .array(array) = self else { return nil }
        return array
    }

    var objectValue: [String: MoonPayJSONValue]? {
        guard case let .object(object) = self else { return nil }
        return object
    }

    func decode<T: Decodable>(_ type: T.Type) throws -> T {
        let data = try MoonPayJSONCoding.makeEncoder().encode(self)
        return try MoonPayJSONCoding.makeDecoder().decode(type, from: data)
    }
}
