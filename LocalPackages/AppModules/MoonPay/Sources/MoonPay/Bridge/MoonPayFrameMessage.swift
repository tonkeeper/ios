import Foundation

/// The envelope every frame message travels in, in both directions:
/// `{"version": 2, "meta": {"channelId": "…"}, "kind": "…", "payload": {…}}` serialized as a JSON string.
public struct MoonPayFrameMessage: Codable, Equatable, Sendable {
    public struct Meta: Codable, Equatable, Sendable {
        public let channelId: String

        public init(channelId: String) {
            self.channelId = channelId
        }
    }

    public static let protocolVersion = 2

    public let version: Int
    public let meta: Meta
    public let kind: String
    public let payload: MoonPayJSONValue?

    public init(kind: String, channelId: String, payload: MoonPayJSONValue? = nil) {
        version = Self.protocolVersion
        meta = Meta(channelId: channelId)
        self.kind = kind
        self.payload = payload
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? Self.protocolVersion
        meta = try container.decode(Meta.self, forKey: .meta)
        kind = try container.decode(String.self, forKey: .kind)
        payload = try container.decodeIfPresent(MoonPayJSONValue.self, forKey: .payload)
    }

    public var channelId: String {
        meta.channelId
    }

    public static func decode(jsonString: String) throws -> MoonPayFrameMessage {
        guard let data = jsonString.data(using: .utf8) else {
            throw MoonPayFrameError.malformedMessage("message is not UTF-8")
        }
        do {
            return try MoonPayJSONCoding.makeDecoder().decode(MoonPayFrameMessage.self, from: data)
        } catch {
            throw MoonPayFrameError.malformedMessage(String(describing: error))
        }
    }

    public func encodedJSONString() throws -> String {
        let data = try MoonPayJSONCoding.makeEncoder().encode(self)
        guard let string = String(data: data, encoding: .utf8) else {
            throw MoonPayFrameError.malformedMessage("message is not UTF-8")
        }
        return string
    }

    /// Frames listen for `window.postMessage` carrying the envelope as a **string**, so the JSON is
    /// embedded as a JavaScript string literal rather than an object literal.
    public func javaScriptPostMessageStatement() throws -> String {
        try "window.postMessage(\(Self.javaScriptStringLiteral(encodedJSONString())), '*');"
    }

    static func javaScriptStringLiteral(_ string: String) -> String {
        var literal = "\""
        for scalar in string.unicodeScalars {
            switch scalar {
            case "\"": literal += "\\\""
            case "\\": literal += "\\\\"
            case "\n": literal += "\\n"
            case "\r": literal += "\\r"
            case "\t": literal += "\\t"
            // Line and paragraph separators are valid JSON but terminate a JavaScript string literal
            // in engines older than ES2019.
            case "\u{2028}": literal += "\\u2028"
            case "\u{2029}": literal += "\\u2029"
            case let control where control.value < 0x20:
                literal += String(format: "\\u%04x", control.value)
            default:
                literal.unicodeScalars.append(scalar)
            }
        }
        literal += "\""
        return literal
    }
}
