import Foundation

/// Device-scoped session. `deviceId` is bound into every wallet register proof, so both
/// halves have to come from the same registration.
public struct DeviceAuthSession: Hashable, Sendable {
    public let deviceId: String
    public let accessToken: String

    public init(deviceId: String, accessToken: String) {
        self.deviceId = deviceId
        self.accessToken = accessToken
    }
}

/// Diff between the local wallet list and what the backend has bound to this device.
public struct DeviceBindings: Hashable, Sendable {
    /// Sent by the client and bound to this device.
    public let known: [String]
    /// Sent by the client but not bound here — they need `/api/v2/wallets/register`.
    public let unknown: [String]
    /// Bound to this device but not sent by the client.
    public let extra: [String]

    public init(known: [String], unknown: [String], extra: [String]) {
        self.known = known
        self.unknown = unknown
        self.extra = extra
    }
}

enum DeviceAuthError: Error, Equatable {
    case cancelled
    case connectionError
    /// 401 from the auth endpoints; `reason` is the machine-readable body value
    /// (`token_expired`, `refresh_reused`, `device_unknown`, `device_revoked`).
    case unauthorized(reason: String)
    case failed(message: String)
}

extension DeviceAuthError {
    /// The only 401 reason a re-registration with the same keypair cannot fix.
    var isDeviceRevoked: Bool {
        guard case let .unauthorized(reason) = self else { return false }
        return reason.contains(DeviceAuthRevocation.revokedReason)
    }
}

enum DeviceAuthRevocation {
    static let revokedReason = "device_revoked"
}

/// ES256 proof produced by ChainKit: `signature` and `publicKey` are both hex.
struct DeviceProof: Hashable {
    let publicKey: String
    let signature: String
}

struct DeviceTokenPair: Hashable {
    let deviceId: String
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
}
