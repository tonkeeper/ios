public enum TonConnectSignDataPayload: Codable, Equatable {
    case text(text: String)
    case binary(bytes: String)
    case cell(schema: String, cell: String)

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .text(text):
            try container.encode("text", forKey: .type)
            try container.encode(text, forKey: .text)
        case let .binary(bytes):
            try container.encode("binary", forKey: .type)
            try container.encode(bytes, forKey: .bytes)
        case let .cell(schema, cell):
            try container.encode("cell", forKey: .type)
            try container.encode(schema, forKey: .schema)
            try container.encode(cell, forKey: .cell)
        }
    }
}

public extension TonConnectSignDataPayload {
    enum CodingKeys: CodingKey {
        case type
        case text
        case bytes
        case schema
        case cell
    }
}

public extension TonConnectSignDataPayload {
    init(from decoder: Decoder) throws {
        let container: KeyedDecodingContainer<TonConnectSignDataPayload.CodingKeys> = try decoder.container(keyedBy: CodingKeys.self)
        let type: String = try container.decode(String.self, forKey: .type)
        switch type {
        case "text":
            let text = try container.decode(String.self, forKey: .text)
            self = .text(text: text)
        case "binary":
            let bytes = try container.decode(String.self, forKey: .bytes)
            self = .binary(bytes: bytes)
        case "cell":
            let schema = try container.decode(String.self, forKey: .schema)
            let cell = try container.decode(String.self, forKey: .cell)
            self = .cell(schema: schema, cell: cell)
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown type")
        }
    }
}
