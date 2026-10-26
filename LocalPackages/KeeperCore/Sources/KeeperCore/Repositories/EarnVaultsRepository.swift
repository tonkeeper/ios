import Foundation

public protocol EarnVaultsRepository: Sendable {
    func vaults(for featuredVaults: [EarnFeaturedVault]) async throws -> [EarnVault]
}
