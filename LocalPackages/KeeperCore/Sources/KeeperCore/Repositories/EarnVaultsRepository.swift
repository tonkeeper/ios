import Foundation
import TKEarnAPI

public protocol EarnVaultsRepository: Sendable {
    func loadFeaturedVaults() async throws -> [EarnVault]
}

struct EarnVaultsRepositoryImplementation: EarnVaultsRepository, EarnAssetOffersRepository {
    /// `/vaults` takes at most this many underlying assets per request.
    static let underlyingAssetIdsLimit = 20
    /// The vault fiat fields are not rendered, but the request has to name a currency.
    private static let currencies = [Currency.defaultCurrency.code.lowercased()]

    private let api: EarnAPI
    private let isEnabled: @Sendable () -> Bool

    init(api: EarnAPI, isEnabled: @escaping @Sendable () -> Bool) {
        self.api = api
        self.isEnabled = isEnabled
    }

    func loadFeaturedVaults() async throws -> [EarnVault] {
        guard isEnabled() else { return [] }
        return try await api.vaults(currencies: Self.currencies, underlyingAssetIds: nil)
            .map(EarnVault.init(vault:))
    }

    /// Asset ids are matched case-insensitively, as the backend matches them.
    func offers(assetIds: [String]) async throws -> [String: EarnAssetOffer] {
        guard isEnabled() else { return [:] }
        var underlyingAssetIds = [String]()
        var requestedKeys = Set<String>()
        for assetId in assetIds where requestedKeys.insert(Self.key(assetId)).inserted {
            underlyingAssetIds.append(assetId)
        }
        guard !underlyingAssetIds.isEmpty else { return [:] }

        let bestVaults = try await withThrowingTaskGroup(of: [Components.Schemas.Vault].self) { group in
            for chunk in underlyingAssetIds.chunked(into: Self.underlyingAssetIdsLimit) {
                group.addTask {
                    try await api.vaults(currencies: Self.currencies, underlyingAssetIds: chunk)
                }
            }
            var bestVaults = [String: Components.Schemas.Vault]()
            for try await vaults in group {
                for vault in vaults {
                    let key = Self.key(vault.asset.asset_id)
                    if let best = bestVaults[key], best.apy >= vault.apy {
                        continue
                    }
                    bestVaults[key] = vault
                }
            }
            return bestVaults
        }

        return assetIds.reduce(into: [:]) { offers, assetId in
            offers[assetId] = bestVaults[Self.key(assetId)].map { EarnAssetOffer(assetId: assetId, vault: $0) }
        }
    }

    private static func key(_ assetId: String) -> String {
        assetId.lowercased()
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}
