import Foundation

/// Opaque, single-use token created server-side with the secret key; it opens the
/// `check-connection` frame and expires 24 hours after issuance.
public struct MoonPaySessionToken: RawRepresentable, Hashable, Codable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

/// Body of `POST /platform/v1/sessions`.
public struct MoonPayCreateSessionRequest: Encodable, Equatable, Sendable {
    public var deviceIp: String
    public var externalCustomerId: String?
    public var email: String?
    /// E.164.
    public var phoneNumber: String?
    public var termsAcceptedAt: Date?

    public init(
        deviceIp: String,
        externalCustomerId: String? = nil,
        email: String? = nil,
        phoneNumber: String? = nil,
        termsAcceptedAt: Date? = nil
    ) {
        self.deviceIp = deviceIp
        self.externalCustomerId = externalCustomerId
        self.email = email
        self.phoneNumber = phoneNumber
        self.termsAcceptedAt = termsAcceptedAt
    }
}

struct MoonPaySessionResponse: Decodable {
    let sessionToken: String
}
