import Foundation

struct HardcodedEarnVaultsRepository: EarnVaultsRepository {
    private let isEarnEnabled: Bool

    init(isEarnEnabled: Bool) {
        self.isEarnEnabled = isEarnEnabled
    }

    func vaults(for featuredVaults: [EarnFeaturedVault]) async throws -> [EarnVault] {
        guard isEarnEnabled else { return [] }
        let vaults = EarnHardcodedData.vaults
        return featuredVaults.compactMap { featuredVault in
            vaults.first {
                $0.network == featuredVault.network
                    && $0.vaultId.caseInsensitiveCompare(featuredVault.vaultId) == .orderedSame
            }
        }
    }
}
