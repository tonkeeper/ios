import Foundation

@MainActor
public struct LoyaltyReferralCodeRepository {
    private let userDefaults: UserDefaults

    nonisolated init(userDefaults: UserDefaults) {
        self.userDefaults = userDefaults
    }

    public var pendingCode: String? {
        userDefaults.string(forKey: .referralCode)
    }

    public func save(_ code: String) {
        guard pendingCode == nil else { return }
        userDefaults.set(code, forKey: .referralCode)
    }

    public func take() -> String? {
        let code = userDefaults.string(forKey: .referralCode)
        userDefaults.removeObject(forKey: .referralCode)
        return code
    }
}

private extension String {
    static let referralCode = "loyaltyReferralCode"
}
