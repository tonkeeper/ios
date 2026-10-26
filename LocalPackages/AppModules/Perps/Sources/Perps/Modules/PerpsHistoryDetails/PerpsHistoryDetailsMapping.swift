import AppUI
import PerpsModels
import TKLocalize
import TKUIKit
import UIKit

enum PerpsHistoryDetailsMapping {
    struct Market {
        let iconURL: URL?
        let sizeDecimals: Int
    }

    static func model(
        event: PerpsHistoryEvent,
        market: Market?,
        format: PerpsFormatting,
        onShare: (() -> Void)?
    ) -> MultichainTransactionDetailsModel {
        MultichainTransactionDetailsModel(
            image: .single(.init(imageSource: .url(market?.iconURL))),
            amountLines: amount(event, format: format).map { [.init(amount: $0, chain: nil)] } ?? [],
            fiat: nil,
            date: PerpsHistoryEventText.detailsDate(event, date: format.candleDateTime(event.date)),
            tags: tags(event, format: format),
            rows: rows(event, sizeDecimals: market?.sizeDecimals, format: format),
            transactionButton: nil,
            actionButton: onShare.map {
                .init(title: TKLocales.Perps.Asset.share, icon: .TKUIKit.Icons.Size16.shareArrow, action: $0)
            }
        )
    }

    /// Only a closing event with both prices known makes a card worth sharing.
    static func shareSnapshot(event: PerpsHistoryEvent, iconURL: URL?) -> SharePositionSnapshot? {
        guard event.isClosing, let side = event.side, let entryPrice = event.entryPrice, let closePrice = event.closePrice else {
            return nil
        }
        return SharePositionSnapshot(
            coinName: event.symbol,
            iconLetter: event.symbol.prefix(1).uppercased(),
            iconURL: iconURL,
            isLong: side == .long,
            leverage: event.leverage,
            entryPrice: entryPrice,
            currentPrice: closePrice,
            pnlPercent: event.pnlPercent,
            isProfit: (event.pnl ?? event.pnlPercent ?? 0) >= 0,
            date: event.date
        )
    }
}

private extension PerpsHistoryDetailsMapping {
    static func amount(_ event: PerpsHistoryEvent, format: PerpsFormatting) -> String? {
        event.isClosing ? event.pnl.map(format.signedUsd) : event.margin.map(format.usd)
    }

    static func tags(_ event: PerpsHistoryEvent, format: PerpsFormatting) -> [TKTagSwiftUIViewConfig] {
        var tags: [TKTagSwiftUIViewConfig] = []
        if let leverage = event.leverage {
            tags.append(TKTagSwiftUIViewConfig(text: format.leverageBadge(leverage), style: .plain, backgroundPadding: UIEdgeInsets(top: 0, left: 0, bottom: 1, right: 0)))
        }
        if let side = event.side {
            tags.append(.accentTag(
                text: side == .long ? TKLocales.Perps.Asset.long : TKLocales.Perps.Asset.short,
                accent: side == .long ? .accentGreen : .accentRed
            ))
        }
        return tags
    }

    static func rows(
        _ event: PerpsHistoryEvent,
        sizeDecimals: Int?,
        format: PerpsFormatting
    ) -> [MultichainTransactionDetailsCellContent] {
        var rows: [MultichainTransactionDetailsCellContent] = []
        if let entryPrice = event.entryPrice {
            rows.append(.property(title: TKLocales.Perps.Asset.entryPrice, value: format.usd(entryPrice)))
        }
        if event.isClosing, let closePrice = event.closePrice {
            rows.append(.property(title: TKLocales.Perps.HistoryDetails.closePrice, value: format.usd(closePrice)))
        }
        if event.isClosing || event.kind == .increased, let usdSize = event.usdSize {
            let baseSize = event.baseSize.map {
                "≈ " + format.token($0, symbol: event.symbol, decimals: sizeDecimals ?? Self.fallbackSizeDecimals)
            }
            rows.append(.value(title: TKLocales.Perps.Asset.size, value: format.usd(usdSize), subvalue: baseSize))
        }
        if event.isClosing, let pnlPercent = event.pnlPercent {
            rows.append(.property(
                title: pnlPercent >= 0 ? TKLocales.Perps.HistoryDetails.profit : TKLocales.Perps.HistoryDetails.loss,
                value: format.signedPercent(pnlPercent)
            ))
        }
        if let feeUsd = event.feeUsd {
            let fee = event.fee.map { "≈ " + format.token($0.value, symbol: $0.symbol, decimals: Self.feeDecimals) }
            rows.append(.value(title: TKLocales.Perps.Confirm.fee, value: format.usd(feeUsd), subvalue: fee))
        }
        if event.isClosing, let fundingUsd = event.fundingUsd {
            rows.append(.property(title: TKLocales.Perps.Asset.funding, value: format.signedUsd(fundingUsd)))
        }
        return rows
    }

    static let fallbackSizeDecimals = 6
    static let feeDecimals = 6
}
