import BigInt
import Foundation
import KeeperCore
import TKLocalize
import TKUIKit
import TronSwift
import UIKit

@MainActor
struct TradeAssetDetailsScreenMapper {
    let initialHeader: TradeAssetDetailsHeaderViewData

    private let assetID: String
    private let multichainState: MultichainWalletState?
    private let isSwapDisabled: Bool
    private let amountFormatter: AmountFormatter
    private let valueFormatter: TradeAssetDetailsValueFormatter
    private let displayFormatter: TradeAssetDetailsDisplayFormatter

    init(
        multichainState: MultichainWalletState?,
        preview: TradeAssetDetailsViewModel.PreviewContext,
        isSwapDisabled: Bool,
        amountFormatter: AmountFormatter,
        signedAmountFormatter: AmountFormatter,
        currencyProvider: @escaping () -> Currency
    ) {
        self.assetID = preview.assetID
        self.multichainState = multichainState
        self.isSwapDisabled = isSwapDisabled
        self.amountFormatter = amountFormatter
        let valueFormatter = TradeAssetDetailsValueFormatter(
            amountFormatter: amountFormatter,
            signedAmountFormatter: signedAmountFormatter,
            currencyProvider: currencyProvider
        )
        self.valueFormatter = valueFormatter
        self.displayFormatter = TradeAssetDetailsDisplayFormatter(
            amountFormatter: amountFormatter,
            valueFormatter: valueFormatter,
            currencyProvider: currencyProvider
        )
        self.initialHeader = TradeAssetDetailsHeaderViewData(
            title: Self.headerTitle(assetId: preview.assetID, title: preview.title, symbol: preview.symbol),
            imageSource: AssetIdResolver.imageSource(
                for: preview.assetID,
                imageUrl: preview.imageURL,
                multichainEnabled: multichainState != nil
            ),
            subtitle: TradeAssetDetailsViewModel.HeaderSubtitleViewData(
                preview: preview,
                isMultichain: multichainState != nil
            ),
            showsVerificationCheckmark: preview.isTrusted == true,
            earnText: nil
        )
    }

    /// The trading API names the TRON coin after its network, so the header shows the ticker instead.
    private static func headerTitle(assetId: String, title: String?, symbol: String?) -> String {
        if case .tronTrx = TradingAssetToken(assetId: assetId), let symbol {
            return symbol
        }
        return title ?? ""
    }

    func map(
        details: TradingAssetDetails?,
        marketData: TradeAssetDetailsMarketData?,
        balance: TradeAssetDetailsBalanceSnapshot?,
        history: TradeAssetDetailsHistorySectionViewData?,
        multichainHistory: TradeAssetDetailsMultichainHistorySectionViewData?,
        tronFees: TronUsdtFeesSnapshot?,
        isSecureMode: Bool
    ) -> (header: TradeAssetDetailsHeaderViewData, screen: TradeAssetDetailsScreenViewData?) {
        guard let details else {
            return (initialHeader, nil)
        }

        let assetInfo = details.assetInfo
        let formattedVolumeChangeText = details.tradingActivity
            .flatMap(\.volumeChangeText)
            .flatMap(displayFormatter.formatTradingChange)
        let earnText = valueFormatter.earnApyButtonFormatter(assetInfo.earnAPY)

        let header = TradeAssetDetailsHeaderViewData(
            title: Self.headerTitle(assetId: assetInfo.assetId, title: assetInfo.title, symbol: assetInfo.symbol),
            imageSource: AssetIdResolver.imageSource(
                for: assetInfo.assetId,
                imageUrl: assetInfo.imageURL,
                multichainEnabled: multichainState != nil
            ),
            subtitle: TradeAssetDetailsViewModel.HeaderSubtitleViewData(
                assetInfo: assetInfo,
                isMultichain: multichainState != nil
            ),
            showsVerificationCheckmark: assetInfo.isTrusted,
            earnText: earnText
        )

        let balanceSection = balanceSection(balance, isSecureMode: isSecureMode)

        let screen = TradeAssetDetailsScreenViewData(
            id: details.id,
            title: assetInfo.title,
            imageURL: assetInfo.imageURL,
            priceText: marketData?.priceText ?? valueFormatter.formatPrice(assetInfo.price),
            changeText: marketData?.changeText ?? valueFormatter.formatChange(assetInfo.changePercent),
            changeAmountText: marketData?.changeAmountText ?? valueFormatter.formatSignedPrice(assetInfo.changeAmount),
            changeColor: marketData?.changeColor
                ?? ((assetInfo.changePercent ?? 0) < 0 ? .Accent.red : .Accent.green),
            earnText: earnText,
            balance: balanceSection,
            aboutParagraph: details.aboutParagraph,
            overview: details.overview.map {
                TradeAssetDetailsMetricViewData(
                    id: $0.id,
                    title: $0.title,
                    value: displayFormatter.formatOverviewValue($0, assetDecimals: assetInfo.decimals),
                    secondaryValue: displayFormatter.formatOverviewSecondaryValue($0),
                    secondaryValuePositive: $0.secondaryValueIsPositive,
                    hint: $0.hint
                )
            },
            tradingActivity: details.tradingActivity.map { tradingActivity in
                TradeAssetDetailsTradingActivityViewData(
                    volumeText: displayFormatter.formatTradingAmount(tradingActivity.volumeText),
                    volumeChangeText: formattedVolumeChangeText,
                    volumeChangeColor: displayFormatter.isPositive(formattedVolumeChangeText) ? .Accent.green : .Accent.red,
                    volumeChangePositive: displayFormatter.isPositive(formattedVolumeChangeText),
                    buyText: displayFormatter.formatTradingSide(
                        title: TKLocales.BuySellList.buy,
                        value: tradingActivity.buyText
                    ),
                    sellText: displayFormatter.formatTradingSide(
                        title: TKLocales.BuySellList.sell,
                        value: tradingActivity.sellText
                    ),
                    buyFraction: tradingActivity.buyFraction,
                    attributionText: attributionText(source: details.infoSource)
                )
            },
            assetType: multichainState
                .flatMap { _ in
                    TradeAssetDetailsAssetTypeSectionKind(assetInfo: assetInfo)
                },
            tronFees: tronFees.map(tronFeesSection(_:)),
            history: isSecureMode ? history?.maskingAmounts() : history,
            multichainHistory: isSecureMode ? multichainHistory?.maskingAmounts() : multichainHistory,
            links: details.links.map {
                TradeAssetDetailsLinkViewData(
                    id: $0.id,
                    title: $0.title,
                    kind: $0.kind,
                    url: $0.url
                )
            },
            primaryActionTitle: details.primaryActionTitle,
            actionBarState: TradeAssetDetailsActionBarState(
                supportsSwap: details.capabilities.supportsSwap && !isSwapDisabled,
                hasBalance: balanceSection != nil
            ),
            actionButtons: actionButtons(details: details, hasBalance: balanceSection != nil),
            isSendAvailable: balanceSection != nil
        )

        return (header, screen)
    }
}

private extension TradeAssetDetailsScreenMapper {
    func tronFeesSection(_ snapshot: TronUsdtFeesSnapshot) -> TradeAssetDetailsTronFeesViewData {
        if snapshot.hasEnoughForAtLeastOneTransfer {
            return .transfersAvailable(
                TKLocales.TronUsdtFees.TokenDetails.transferAvailability(snapshot.totalTransfersAvailable)
            )
        }

        let formatTRX: (BigUInt) -> String = { [amountFormatter] amount in
            amountFormatter.format(
                amount: amount,
                fractionDigits: TRX.fractionDigits,
                accessory: .none
            )
        }

        if snapshot.isTRXOnlyRegion {
            return .banner(
                TradeAssetDetailsTronFeesViewData.Banner(
                    title: TKLocales.TronUsdtFees.TokenDetails.Banners.TrxInsufficient.title,
                    caption: TKLocales.TronUsdtFees.TokenDetails.Banners.TrxInsufficient.caption(
                        formatTRX(snapshot.requiredTRX),
                        formatTRX(snapshot.trxBalance)
                    ),
                    buttonTitle: TKLocales.TronUsdtFees.Common.Buttons.getTrx,
                    style: .trx
                )
            )
        }

        return .banner(
            TradeAssetDetailsTronFeesViewData.Banner(
                title: TKLocales.TronUsdtFees.TokenDetails.Banners.FeeOptionsInsufficient.title,
                caption: TKLocales.TronUsdtFees.TokenDetails.Banners.FeeOptionsInsufficient.caption,
                buttonTitle: TKLocales.TronUsdtFees.Common.Buttons.allFeeOptions,
                style: .battery
            )
        )
    }

    func balanceSection(
        _ snapshot: TradeAssetDetailsBalanceSnapshot?,
        isSecureMode: Bool
    ) -> TradeAssetDetailsBalanceSectionViewData? {
        guard let snapshot, !snapshot.amount.isZero else {
            return nil
        }

        return TradeAssetDetailsBalanceSectionViewData(
            symbol: snapshot.symbol,
            iconImageSource: AssetIdResolver.imageSource(
                for: assetID,
                imageUrl: snapshot.imageURL,
                multichainEnabled: multichainState != nil
            ),
            amountText: isSecureMode
                ? String.secureModeValueShort
                : displayFormatter.formatBalanceAmount(
                    amount: snapshot.amount,
                    fractionDigits: snapshot.fractionDigits,
                    symbol: snapshot.symbol
                ),
            convertedAmountText: isSecureMode
                ? String.secureModeValueShort
                : displayFormatter.formatBalanceConverted(snapshot.convertedAmount),
            chainTag: snapshot.tagText ?? AssetIdResolver.tag(
                for: assetID,
                multichainEnabled: multichainState != nil
            ),
            freshness: snapshot.freshness
        )
    }

    func attributionText(source: TradingAssetInfoSource) -> AttributedString {
        var text = AttributedString(
            TKLocales.Trade.AssetDetails.TradingActivity.attribution(source.displayedName)
        )
        if let url = source.url, let range = text.range(of: source.displayedName) {
            text[range].link = url
        }
        return text
    }

    func actionButtons(details: TradingAssetDetails, hasBalance: Bool) -> [TradeAssetDetailsActionButton] {
        var buttons: [TradeAssetDetailsActionButton] = []
        if hasBalance {
            buttons.append(.send)
        }
        buttons.append(.receive)
        if multichainState != nil, details.capabilities.supportsOnramp {
            buttons.append(.cashBuy)
        }
        if hasBalance, multichainState != nil, details.capabilities.supportsOfframp {
            buttons.append(.cashSell)
        }
        return buttons
    }
}

private extension TradeAssetDetailsHistorySectionViewData {
    func maskingAmounts() -> TradeAssetDetailsHistorySectionViewData {
        TradeAssetDetailsHistorySectionViewData(
            items: items.map { item in
                TradeAssetDetailsHistoryItemViewData(
                    id: item.id,
                    icon: item.icon,
                    title: item.title,
                    subtitle: item.subtitle,
                    amountText: .secureModeValueShort,
                    amountStyle: item.amountStyle,
                    dateText: item.dateText
                )
            }
        )
    }
}

private extension TradeAssetDetailsMultichainHistorySectionViewData {
    func maskingAmounts() -> TradeAssetDetailsMultichainHistorySectionViewData {
        TradeAssetDetailsMultichainHistorySectionViewData(
            items: items.map { item in
                MultichainHistoryActivityItem(
                    id: item.id,
                    activity: item.activity,
                    title: item.title,
                    subtitle: item.subtitle,
                    comment: item.comment,
                    time: item.time,
                    icon: item.icon,
                    primaryAmount: item.primaryAmount?.masked(),
                    secondaryAmount: item.secondaryAmount?.masked(),
                    status: item.status,
                    nft: item.nft
                )
            }
        )
    }
}

private extension MultichainHistoryActivityItem.Amount {
    func masked() -> Self {
        MultichainHistoryActivityItem.Amount(
            text: .secureModeValueShort,
            chainTitle: chainTitle,
            style: style
        )
    }
}
