import Foundation

public enum MoonPayConnectionStatus: String, Codable, CaseIterable, Sendable {
    case active
    case connectionRequired
    case termsAcceptanceRequired
    case pending
    case unavailable
    case failed
}

public struct MoonPayCustomer: Codable, Equatable, Sendable {
    public let id: String
    public let country: String?
    public let administrativeArea: String?

    public init(id: String, country: String? = nil, administrativeArea: String? = nil) {
        self.id = id
        self.country = country
        self.administrativeArea = administrativeArea
    }
}

/// Credentials as they leave a frame: base64 of a JSON envelope encrypted to the host's X25519
/// public key. See `MoonPayCredentialsDecryptor`.
public struct MoonPayEncryptedCredentials: Codable, Equatable, Sendable {
    public let base64: String

    public init(base64: String) {
        self.base64 = base64
    }

    public init(from decoder: Decoder) throws {
        base64 = try decoder.singleValueContainer().decode(String.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(base64)
    }
}

/// `complete` payload of the `check-connection` and `connect` frames.
public struct MoonPayConnectionResult: Decodable, Equatable, Sendable {
    public let status: MoonPayConnectionStatus
    public let encryptedCredentials: MoonPayEncryptedCredentials?
    public let customer: MoonPayCustomer?
    /// `check-connection` sets this when the session belongs to a different customer than the
    /// one connected on this device.
    public let mismatch: Bool?
    public let reason: String?

    public init(
        status: MoonPayConnectionStatus,
        encryptedCredentials: MoonPayEncryptedCredentials? = nil,
        customer: MoonPayCustomer? = nil,
        mismatch: Bool? = nil,
        reason: String? = nil
    ) {
        self.status = status
        self.encryptedCredentials = encryptedCredentials
        self.customer = customer
        self.mismatch = mismatch
        self.reason = reason
    }

    private enum CodingKeys: String, CodingKey {
        case status
        case encryptedCredentials = "credentials"
        case customer
        case mismatch
        case reason
    }
}

/// Decrypted frame credentials. Held in memory only; `accessToken` authenticates API calls,
/// `clientToken` opens further frames.
public struct MoonPayCredentials: Codable, Equatable, Sendable {
    public let accessToken: String
    public let clientToken: String
    public let expiresAt: Date

    public init(accessToken: String, clientToken: String, expiresAt: Date) {
        self.accessToken = accessToken
        self.clientToken = clientToken
        self.expiresAt = expiresAt
    }

    public func isExpired(at date: Date = Date()) -> Bool {
        expiresAt <= date
    }
}
