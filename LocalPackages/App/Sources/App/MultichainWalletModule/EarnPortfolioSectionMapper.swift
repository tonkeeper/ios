import AppUI
import Foundation
import KeeperCore
import TKUIKit

struct EarnPortfolioSectionMapper {
    let fiatFormatter: (Decimal) -> String

    func map(_ positions: [EarnPosition], isStale: Bool) -> EarnPortfolioSectionState {
        EarnPortfolioSectionState(
            totalBalance: fiatFormatter(positions.reduce(0) { $0 + $1.balanceUsd }),
            isStale: isStale,
            rows: positions.map(row)
        )
    }

    private func row(_ position: EarnPosition) -> AssetBalanceRowCellContent {
        let chain = MultichainChain(earnNetwork: position.network)
        return AssetBalanceRowCellContent(
            id: position.rowId,
            title: position.assetSymbol,
            badge: chain?.badgeTitle ?? position.network.uppercased(),
            displayMode: .includingMarketData(
                marketCap: position.protocolName,
                price: fiatFormatter(position.balanceUsd),
                change: position.earnedUsd.map { earned in
                    .init(
                        text: earned >= 0 ? "+\(fiatFormatter(earned))" : fiatFormatter(earned),
                        isPositive: earned >= 0
                    )
                },
                showsPin: false
            ),
            avatarImageSource: .url(position.assetIconURL, chainIcon: chain?.tokenIcon20)
        )
    }
}

extension EarnPosition {
    var rowId: String {
        "\(network)/\(vaultId)"
    }
}
