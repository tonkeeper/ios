import Foundation
@testable import KeeperCore
import TKEarnAPI

actor EarnAPIStub: EarnAPI {
    struct VaultsRequest: Equatable {
        let currencies: [String]
        let underlyingAssetIds: [String]?
    }

    struct BalanceRequest: Equatable {
        let walletId: String
        let currencies: [String]
        var refresh = false
    }

    private(set) var vaultsRequests = [VaultsRequest]()
    private(set) var balanceRequests = [BalanceRequest]()
    private var vaults: @Sendable ([String]?) -> Result<[Components.Schemas.Vault], EarnAPIError>
    private var balance: Result<Components.Schemas.Balance, EarnAPIError>

    init(
        vaults: @escaping @Sendable ([String]?) -> Result<[Components.Schemas.Vault], EarnAPIError> = { _ in .success([]) },
        balance: Result<Components.Schemas.Balance, EarnAPIError> = .success(EarnFixtures.balance())
    ) {
        self.vaults = vaults
        self.balance = balance
    }

    func setBalance(_ balance: Result<Components.Schemas.Balance, EarnAPIError>) {
        self.balance = balance
    }

    func vaults(
        currencies: [String],
        underlyingAssetIds: [String]?
    ) async throws(EarnAPIError) -> [Components.Schemas.Vault] {
        vaultsRequests.append(VaultsRequest(currencies: currencies, underlyingAssetIds: underlyingAssetIds))
        return try vaults(underlyingAssetIds).get()
    }

    func walletBalance(
        walletId: String,
        currencies: [String],
        refresh: Bool
    ) async throws(EarnAPIError) -> Components.Schemas.Balance {
        balanceRequests.append(BalanceRequest(walletId: walletId, currencies: currencies, refresh: refresh))
        return try balance.get()
    }
}

enum EarnFixtures {
    static let usdcAssetId = "eth/mainnet/erc20/0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48"
    static let usdtAssetId = "eth/mainnet/erc20/0xdac17f958d2ee523a2206206994597c13d831ec7"

    static func vault(
        underlyingAssetId: String = usdcAssetId,
        symbol: String = "USDC",
        protocolName: String = "Aave",
        apy: Double = 0.0373,
        network: String = "mainnet",
        vaultId: String = "0x98C23E9d8f34FEFb1B7BD6a91B7FF122F4e16F5c",
        image: String = ""
    ) -> Components.Schemas.Vault {
        Components.Schemas.Vault(
            asset_id: "eth/mainnet/erc20/\(vaultId.lowercased())",
            symbol: "a\(symbol)",
            name: "\(protocolName) \(symbol)",
            asset: Components.Schemas.AssetInfo(
                asset_id: underlyingAssetId,
                name: symbol,
                symbol: symbol,
                decimals: 6,
                image: image
            ),
            protocol_name: protocolName,
            protocol_logo: "",
            apy: apy,
            tvl_fiat: Components.Schemas.FiatValue(additionalProperties: ["USD": "1000000"]),
            score: 90,
            vaults_fyi: Components.Schemas.VaultsFyiRef(network: network, vault_id: vaultId)
        )
    }

    static func position(
        vault: Components.Schemas.Vault = vault(),
        balanceFiat: [String: String] = ["USD": "0.2002"],
        earnedFiat: [String: String] = ["USD": "0.000239"]
    ) -> Components.Schemas.Position {
        Components.Schemas.Position(
            vault: vault,
            balance: "200200",
            balance_fiat: Components.Schemas.FiatValue(additionalProperties: balanceFiat),
            earned_fiat: Components.Schemas.FiatValue(additionalProperties: earnedFiat)
        )
    }

    static func balance(
        totalFiat: [String: String] = ["USD": "0.2002"],
        updatedAt: Date = Date(),
        positions: [Components.Schemas.Position] = [position()]
    ) -> Components.Schemas.Balance {
        Components.Schemas.Balance(
            total_fiat: Components.Schemas.FiatValue(additionalProperties: totalFiat),
            updated_at: updatedAt,
            positions: positions
        )
    }
}
