import Foundation
import TKEarnAPI

extension EarnVault {
    init(vault: Components.Schemas.Vault) {
        self.init(
            network: vault.vaults_fyi.network,
            vaultId: vault.vaults_fyi.vault_id,
            assetSymbol: vault.asset.symbol,
            protocolName: vault.protocol_name,
            apy: Decimal(earnAPYFraction: vault.apy),
            iconURL: URL(earnImage: vault.asset.image)
        )
    }
}

extension EarnPortfolio {
    init(walletId: String, balance: Components.Schemas.Balance) {
        self.init(
            walletId: walletId,
            totalFiat: [String: Decimal](earnFiat: balance.total_fiat),
            positions: balance.positions.map(EarnPosition.init(position:))
        )
    }
}

extension EarnPosition {
    init(position: Components.Schemas.Position) {
        self.init(
            network: position.vault.vaults_fyi.network,
            vaultId: position.vault.vaults_fyi.vault_id,
            protocolName: position.vault.protocol_name,
            assetSymbol: position.vault.asset.symbol,
            assetIconURL: URL(earnImage: position.vault.asset.image),
            balanceFiat: [String: Decimal](earnFiat: position.balance_fiat),
            earnedFiat: [String: Decimal](earnFiat: position.earned_fiat)
        )
    }
}

extension [String: Decimal] {
    /// Keyed by upper-case currency code, which the backend promises; an amount that does not parse
    /// is left out like a currency without a rate.
    init(earnFiat: Components.Schemas.FiatValue) {
        self = earnFiat.additionalProperties.reduce(into: [:]) { amounts, entry in
            guard let amount = Decimal(string: entry.value) else { return }
            amounts[entry.key.uppercased()] = amount
        }
    }
}

extension EarnAssetOffer {
    init(assetId: String, vault: Components.Schemas.Vault) {
        self.init(
            assetId: assetId,
            network: vault.vaults_fyi.network,
            vaultId: vault.vaults_fyi.vault_id,
            apy: Decimal(earnAPYFraction: vault.apy)
        )
    }
}

extension Decimal {
    /// The backend states APY as a fraction (0.0534) and the app renders percents. Going through the
    /// double's shortest text keeps 0.0534 from turning into 5.3399999….
    init(earnAPYFraction fraction: Double) {
        self = (Decimal(string: String(fraction)) ?? Decimal(fraction)) * 100
    }
}

extension URL {
    /// The backend sends an empty string for an image it does not know.
    init?(earnImage: String) {
        guard !earnImage.isEmpty else { return nil }
        self.init(string: earnImage)
    }
}
