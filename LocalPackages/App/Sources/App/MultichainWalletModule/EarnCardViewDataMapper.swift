import AppUI
import Foundation
import KeeperCore

enum EarnCardViewDataMapper {
    static func cards(
        _ vaults: [EarnVault],
        apyFormatter: (Decimal) -> String
    ) -> [EarnCardViewData] {
        vaults.map { vault in
            EarnCardViewData(
                network: vault.network,
                vaultId: vault.vaultId,
                title: vault.assetSymbol,
                apy: apyFormatter(vault.apy),
                protocolName: vault.protocolName,
                imageSource: .url(
                    vault.iconURL,
                    chainIcon: MultichainChain(earnNetwork: vault.network)?.tokenIcon20
                )
            )
        }
    }
}
