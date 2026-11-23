import AppUI
import Foundation
import KeeperCore
import TKUIKit

struct EarnPortfolioSectionMapper {
    let displayCurrency: () -> Currency
    let isSecureMode: () -> Bool
    let fiatFormatter: (Decimal, Currency) -> String

    /// Every amount is in one currency: the display one, or the default currency standing in when the
    /// backend had no rate for it.
    func map(_ portfolio: EarnPortfolio, isStale: Bool) -> EarnPortfolioSectionState {
        let displayCurrency = displayCurrency()
        let currency = portfolio.totalFiat[displayCurrency.code] == nil ? Currency.defaultCurrency : displayCurrency
        let isSecureMode = isSecureMode()
        return EarnPortfolioSectionState(
            totalBalance: amount(portfolio.totalFiat[currency.code], currency: currency, isSecureMode: isSecureMode),
            isStale: isStale,
            rows: portfolio.positions.map { row($0, currency: currency, isSecureMode: isSecureMode) }
        )
    }

    /// Secure mode hides the earnings outright: their color alone would tell a gain from a loss.
    private func row(_ position: EarnPosition, currency: Currency, isSecureMode: Bool) -> AssetBalanceRowCellContent {
        let chain = MultichainChain(earnNetwork: position.network)
        return AssetBalanceRowCellContent(
            id: position.rowId,
            title: position.assetSymbol,
            badge: chain?.badgeTitle ?? position.network.uppercased(),
            displayMode: .includingMarketData(
                marketCap: position.protocolName,
                price: amount(position.balanceFiat[currency.code], currency: currency, isSecureMode: isSecureMode),
                change: isSecureMode ? nil : earnedDelta(position.earnedFiat[currency.code], currency: currency),
                showsPin: false
            ),
            avatarImageSource: .url(position.assetIconURL, chainIcon: chain?.tokenIcon20)
        )
    }

    /// The backend leaves out a currency it has no rate for, so a missing amount is unknown, not zero.
    private func amount(_ value: Decimal?, currency: Currency, isSecureMode: Bool) -> String {
        if isSecureMode {
            return .secureModeValueShort
        }
        return value.map { fiatFormatter($0, currency) } ?? "-"
    }

    /// The backend sends zero also when it could not tell the earnings, so zero says nothing.
    private func earnedDelta(_ earned: Decimal?, currency: Currency) -> AssetBalanceRowCellContent.Delta? {
        guard let earned, !earned.isZero else { return nil }
        return AssetBalanceRowCellContent.Delta(
            text: earned > 0 ? "+\(fiatFormatter(earned, currency))" : fiatFormatter(earned, currency),
            isPositive: earned > 0
        )
    }
}

extension EarnPosition {
    var rowId: String {
        "\(network)/\(vaultId)"
    }
}
