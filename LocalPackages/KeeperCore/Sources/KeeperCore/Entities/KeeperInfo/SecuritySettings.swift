import Foundation

/// Shared security settings for all wallets in the app
public struct SecuritySettings: Equatable {
    public let isBiometryEnabled: Bool
    public let isLockScreen: Bool

    /// Cumulative count of consecutive failed passcode attempts. Reset to 0 on a successful unlock.
    public let failedPasscodeAttempts: Int

    /// Timestamp until which the passcode input is locked out. `nil` when not locked.
    /// Stored as an absolute end-time so the lockout survives app relaunch (it is not a running timer).
    public let passcodeLockoutEndDate: Date?

    public init(
        isBiometryEnabled: Bool,
        isLockScreen: Bool,
        failedPasscodeAttempts: Int = 0,
        passcodeLockoutEndDate: Date? = nil
    ) {
        self.isBiometryEnabled = isBiometryEnabled
        self.isLockScreen = isLockScreen
        self.failedPasscodeAttempts = failedPasscodeAttempts
        self.passcodeLockoutEndDate = passcodeLockoutEndDate
    }

    /// Returns a copy with only the passed fields changed; omitted fields keep their current value.
    /// Pass `passcodeLockoutEndDate: .some(nil)` to clear the lockout (the outer optional distinguishes
    /// "leave unchanged" from "set to nil"). Keeps callers from having to re-list every field on each
    /// update, which is how a newly added field can silently get reset.
    public func updating(
        isBiometryEnabled: Bool? = nil,
        isLockScreen: Bool? = nil,
        failedPasscodeAttempts: Int? = nil,
        passcodeLockoutEndDate: Date?? = nil
    ) -> SecuritySettings {
        SecuritySettings(
            isBiometryEnabled: isBiometryEnabled ?? self.isBiometryEnabled,
            isLockScreen: isLockScreen ?? self.isLockScreen,
            failedPasscodeAttempts: failedPasscodeAttempts ?? self.failedPasscodeAttempts,
            passcodeLockoutEndDate: passcodeLockoutEndDate ?? self.passcodeLockoutEndDate
        )
    }
}

extension SecuritySettings: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.isBiometryEnabled = (try? container.decode(Bool.self, forKey: .isBiometryEnabled)) ?? false
        self.isLockScreen = (try? container.decode(Bool.self, forKey: .isLockScreen)) ?? false
        self.failedPasscodeAttempts = (try? container.decode(Int.self, forKey: .failedPasscodeAttempts)) ?? 0
        self.passcodeLockoutEndDate = try? container.decode(Date.self, forKey: .passcodeLockoutEndDate)
    }
}
