import Foundation

public struct MoonPayErrorDetail: Decodable, Equatable, Sendable {
    public struct Details: Decodable, Equatable, Sendable {
        public let minBuyAmount: String?
        public let maxBuyAmount: String?

        public init(minBuyAmount: String? = nil, maxBuyAmount: String? = nil) {
            self.minBuyAmount = minBuyAmount
            self.maxBuyAmount = maxBuyAmount
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            minBuyAmount = try container.decodeLenientStringIfPresent(forKey: .minBuyAmount)
            maxBuyAmount = try container.decodeLenientStringIfPresent(forKey: .maxBuyAmount)
        }

        private enum CodingKeys: String, CodingKey {
            case minBuyAmount, maxBuyAmount
        }
    }

    public let code: String?
    public let field: String?
    public let message: String?
    public let details: Details?

    public init(code: String? = nil, field: String? = nil, message: String? = nil, details: Details? = nil) {
        self.code = code
        self.field = field
        self.message = message
        self.details = details
    }
}

/// The bound a quote request's `source.amount` fell outside of, in the quote's fiat currency.
public enum MoonPayBuyAmountLimit: Equatable, Sendable {
    case belowMinimum(Decimal)
    case aboveMaximum(Decimal)
}

public enum MoonPayFrameError: Error, Equatable, Sendable, LocalizedError {
    /// Payload of a frame's `error` event.
    public struct Remote: Equatable, Sendable {
        public let code: String
        public let message: String
        public let errors: [MoonPayErrorDetail]?

        public init(code: String, message: String, errors: [MoonPayErrorDetail]? = nil) {
            self.code = code
            self.message = message
            self.errors = errors
        }

        public init(payload: MoonPayJSONValue?) {
            code = payload?["code"]?.stringValue ?? "unknown"
            message = payload?["message"]?.stringValue ?? "Unknown error"
            errors = payload?["errors"].flatMap { try? $0.decode([MoonPayErrorDetail].self) }
        }
    }

    case invalidURL
    case malformedMessage(String)
    case remote(Remote)
    case loadFailed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidURL: "MoonPay frame URL could not be built"
        case let .malformedMessage(reason): "Malformed MoonPay frame message: \(reason)"
        case let .remote(remote): "MoonPay frame error \(remote.code): \(remote.message)"
        case let .loadFailed(reason): "MoonPay frame failed to load: \(reason)"
        }
    }
}

/// Error body of the Platform API.
public struct MoonPayServerError: Decodable, Equatable, Sendable {
    public let code: String?
    public let message: String?
    public let errors: [MoonPayErrorDetail]?

    public init(code: String? = nil, message: String? = nil, errors: [MoonPayErrorDetail]? = nil) {
        self.code = code
        self.message = message
        self.errors = errors
    }
}

public enum MoonPayAPIError: Error, Sendable, LocalizedError {
    case invalidURL
    case encoding(Error)
    case transport(Error)
    case invalidResponse
    case http(status: Int, body: MoonPayServerError?)
    case rateLimited(body: MoonPayServerError?)
    case decoding(Error)

    /// Set when a quote was rejected because the amount is under the minimum or over the maximum.
    public var buyAmountLimit: MoonPayBuyAmountLimit? {
        guard case let .http(_, body) = self else { return nil }
        let posix = Locale(identifier: "en_US_POSIX")
        for detail in body?.errors ?? [] where detail.field == "source.amount" {
            if let value = detail.details?.minBuyAmount.flatMap({ Decimal(string: $0, locale: posix) }) {
                return .belowMinimum(value)
            }
            if let value = detail.details?.maxBuyAmount.flatMap({ Decimal(string: $0, locale: posix) }) {
                return .aboveMaximum(value)
            }
        }
        return nil
    }

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            "MoonPay API URL could not be built"
        case let .encoding(error):
            "MoonPay API request could not be encoded: \(error.localizedDescription)"
        case let .transport(error):
            "MoonPay API request failed: \(error.localizedDescription)"
        case .invalidResponse:
            "MoonPay API returned a non-HTTP response"
        case let .http(status, body):
            "MoonPay API HTTP \(status)" + Self.describe(body)
        case let .rateLimited(body):
            "MoonPay API rate limit exceeded" + Self.describe(body)
        case let .decoding(error):
            "MoonPay API response could not be decoded: \(error.localizedDescription)"
        }
    }

    private static func describe(_ body: MoonPayServerError?) -> String {
        guard let body else { return "" }
        var parts: [String] = []
        if let code = body.code { parts.append(code) }
        if let message = body.message { parts.append(message) }
        if let errors = body.errors, !errors.isEmpty {
            parts.append(errors.map { [$0.field, $0.message].compactMap { $0 }.joined(separator: ": ") }.joined(separator: "; "))
        }
        return parts.isEmpty ? "" : " (\(parts.joined(separator: " — ")))"
    }
}

public enum MoonPayCryptoError: Error, Equatable, Sendable, LocalizedError {
    case invalidEnvelope
    case invalidHex(field: String)
    case invalidEphemeralPublicKey
    case invalidTag
    case decryptionFailed
    case invalidPlaintext

    public var errorDescription: String? {
        switch self {
        case .invalidEnvelope: "MoonPay credentials envelope is not base64 JSON"
        case let .invalidHex(field): "MoonPay credentials field \(field) is not hex"
        case .invalidEphemeralPublicKey: "MoonPay credentials carry an invalid ephemeral public key"
        case .invalidTag: "MoonPay credentials ciphertext is shorter than the authentication tag"
        case .decryptionFailed: "MoonPay credentials could not be decrypted"
        case .invalidPlaintext: "MoonPay credentials plaintext is not the expected JSON"
        }
    }
}
