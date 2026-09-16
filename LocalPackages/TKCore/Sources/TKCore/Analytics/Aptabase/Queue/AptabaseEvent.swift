import Foundation

struct AptabaseEvent: Codable, Equatable {
    struct SystemProps: Codable, Equatable {
        let isDebug: Bool
        let locale: String
        let osName: String
        let osVersion: String
        let appVersion: String
        let appBuildNumber: String
        let sdkVersion: String
        let deviceModel: String
    }

    let timestamp: Date
    let sessionId: String
    let eventName: String
    let systemProps: SystemProps
    let props: [String: AptabasePropValue]
}

enum AptabasePropValue: Codable, Equatable {
    case integer(Int)
    case double(Double)
    case string(String)
    case boolean(Bool)

    /// Mirrors `Aptabase.toCodableProps` coercion order exactly: a value arriving as `NSNumber`
    /// bridges into several of these cases at once, so a different order would silently move a
    /// property between the server's numeric and string columns.
    init?(analyticsValue value: Any) {
        if let value = value as? Int {
            self = .integer(value)
        } else if let value = value as? Double {
            self = .double(value)
        } else if let value = value as? String {
            self = .string(value)
        } else if let value = value as? Float {
            // JSON has no float/double distinction, so keeping a separate case would only make the
            // storage round trip asymmetric. The position in the chain still mirrors the SDK.
            self = .double(Double(value))
        } else if let value = value as? Bool {
            self = .boolean(value)
        } else {
            return nil
        }
    }

    /// Failsafe only: `AptabaseTransportProperty.normalized` runs first and flattens everything the SDK
    /// cannot encode, so both transports see the same props by the time either of them drops anything.
    static func props(from args: [String: Any]) -> [String: AptabasePropValue] {
        args.reduce(into: [:]) { result, element in
            result[element.key] = AptabasePropValue(analyticsValue: element.value)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(Bool.self) {
            self = .boolean(value)
        } else if let value = try? container.decode(Int.self) {
            self = .integer(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported Aptabase property value"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .integer(value):
            try container.encode(value)
        case let .double(value):
            try container.encode(value)
        case let .string(value):
            try container.encode(value)
        case let .boolean(value):
            try container.encode(value)
        }
    }
}

enum AptabaseCoding {
    /// Format expected by the ingestion API, identical to the SDK's encoder.
    static let wireEncoder: JSONEncoder = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .formatted(formatter)
        return encoder
    }()

    /// Storage keeps full timestamp precision so a round trip through disk is lossless.
    static let storageEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        return encoder
    }()

    static let storageDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return decoder
    }()
}
