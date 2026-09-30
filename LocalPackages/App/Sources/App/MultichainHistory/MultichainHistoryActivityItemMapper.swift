import BigInt
import Foundation
import KeeperCore
import TKLocalize
import TKUIKit
import UIKit

@MainActor
struct MultichainHistoryActivityItemMapper {
    private enum AmountSign {
        case positive
        case negative
    }

    private let signedAmountFormatter: AmountFormatter
    private let dateFormatter: DateFormatter
    private let nftProvider: (MultichainActivity) -> MultichainActivityNFT?

    init(
        amountFormatter: AmountFormatter,
        dateFormatter: DateFormatter,
        nftProvider: @escaping (MultichainActivity) -> MultichainActivityNFT? = { _ in nil }
    ) {
        var signedConfiguration = amountFormatter.config
        signedConfiguration.signPolicy = .always
        self.signedAmountFormatter = AmountFormatter(configuration: signedConfiguration)
        self.dateFormatter = dateFormatter
        self.nftProvider = nftProvider
    }

    func makeItem(activity: MultichainActivity) -> MultichainHistoryActivityItem {
        let nft = nftProvider(activity)
        return MultichainHistoryActivityItem(
            id: activityID(for: activity),
            activity: activity,
            title: title(for: activity),
            subtitle: subtitle(for: activity),
            comment: comment(for: activity, nft: nft),
            time: timeString(for: activity.blockTime),
            icon: icon(for: activity),
            primaryAmount: primaryAmount(for: activity, nft: nft),
            secondaryAmount: nft == nil ? secondaryAmount(for: activity) : nil,
            status: activity.status,
            nft: nft
        )
    }

    func activityID(for activity: MultichainActivity) -> MultichainHistoryActivityItem.ID {
        MultichainHistoryActivityIdentity(activity: activity)
    }

    func nft(for activity: MultichainActivity) -> MultichainActivityNFT? {
        nftProvider(activity)
    }

    private static let nftAmount = MultichainHistoryActivityItem.Amount(
        text: MultichainActivityNFT.amountTitle,
        chainTitle: nil,
        style: .primary
    )
}

private extension MultichainHistoryActivityItemMapper {
    func title(for activity: MultichainActivity) -> String {
        // "Sent" would claim a transaction that has not made it into a block yet, so a pending
        // activity reads in the progressive tense instead.
        MultichainActivityPresentationKind(activity: activity)
            .title(isPending: activity.status == .pending)
    }

    func subtitle(for activity: MultichainActivity) -> String? {
        if activity.activityType.isPerps {
            return activity.perps?.symbol.map(TKLocales.MultichainHistory.Perps.subtitle)
        }

        if let stakingProvider = MultichainHistoryStakingProvider(activity: activity) {
            return stakingProvider.displayName
        }

        let addressContext: (address: String, chain: MultichainChain?)?
        switch activity.direction {
        case .incoming:
            addressContext = (activity.fromAddress ?? activity.walletAddress).map {
                ($0, activity.fromChain)
            }
        case .outgoing:
            addressContext = (activity.toAddress ?? activity.walletAddress).map {
                ($0, activity.toChain)
            }
        case .selfTransfer:
            if let walletAddress = activity.walletAddress {
                addressContext = (walletAddress, activity.toChain)
            } else if let toAddress = activity.toAddress {
                addressContext = (toAddress, activity.toChain)
            } else if let fromAddress = activity.fromAddress {
                addressContext = (fromAddress, activity.fromChain)
            } else {
                addressContext = nil
            }
        }

        if let addressContext, let chain = addressContext.chain {
            return MultichainAddressFormatter.shortAddress(
                addressContext.address,
                chain: chain
            )
        }

        return activity.protocolName
    }

    func comment(for activity: MultichainActivity, nft: MultichainActivityNFT?) -> String? {
        switch MultichainActivityPresentationKind(activity: activity) {
        case .dnsRenew:
            return nft == nil ? activity.protocolName : nil
        case .send, .receive, .swap, .stake, .unstake, .mint, .burn,
             .incomingFallback, .outgoingFallback, .perpsOpened, .perpsClosed,
             .perpsLiquidated, .perpsTakeProfit, .perpsStopLoss, .perpsDeposit,
             .perpsWithdrawal:
            return activity.comment
        }
    }

    func icon(for activity: MultichainActivity) -> UIImage {
        if let stakingProvider = MultichainHistoryStakingProvider(activity: activity) {
            return stakingProvider.icon
        }
        return MultichainActivityPresentationKind(activity: activity).icon
    }

    func primaryAmount(
        for activity: MultichainActivity,
        nft: MultichainActivityNFT?
    ) -> MultichainHistoryActivityItem.Amount? {
        let kind = MultichainActivityPresentationKind(activity: activity)
        // A renewal transfers nothing, so the network fee is the only value it costs the wallet.
        if kind == .dnsRenew {
            return amount(
                rawAmount: activity.feeAmount,
                token: activity.feeToken,
                sign: .negative,
                displaysNativeTonAsGram: true
            )
        }

        if nft != nil {
            return Self.nftAmount
        }

        switch kind.amountSide(for: activity) {
        case .incoming, .both:
            return amount(
                rawAmount: activity.inAmount,
                token: activity.inToken,
                sign: .positive,
                displaysNativeTonAsGram: true
            )
        case .outgoing:
            return amount(
                rawAmount: activity.outAmount,
                token: activity.outToken,
                sign: .negative,
                displaysNativeTonAsGram: true
            )
        }
    }

    func secondaryAmount(for activity: MultichainActivity) -> MultichainHistoryActivityItem.Amount? {
        guard MultichainActivityPresentationKind(activity: activity).amountSide(for: activity) == .both else {
            return nil
        }

        return amount(
            rawAmount: activity.outAmount,
            token: activity.outToken,
            sign: .negative,
            displaysNativeTonAsGram: true
        )
    }

    private func amount(
        rawAmount: String?,
        token: MultichainAssetDetails?,
        sign: AmountSign,
        displaysNativeTonAsGram: Bool = false
    ) -> MultichainHistoryActivityItem.Amount? {
        guard let rawAmount, let token else {
            return nil
        }

        let symbol = displaySymbol(
            for: token,
            displaysNativeTonAsGram: displaysNativeTonAsGram
        )
        let title: String
        if let amount = unsignedAmount(from: rawAmount) {
            title = signedAmountFormatter.format(
                amount: amount,
                fractionDigits: token.decimals,
                accessory: .tokenSymbol(symbol),
                isNegative: sign == .negative,
                style: .compact
            )
        } else {
            title = fallbackAmountTitle(
                rawAmount: rawAmount,
                symbol: symbol,
                sign: sign
            )
        }
        let chainTitle: String?
        switch AssetIdComponents(assetId: token.assetId) {
        case .coin:
            chainTitle = nil
        default:
            chainTitle = token.chain?.symbol
        }
        switch sign {
        case .positive:
            return MultichainHistoryActivityItem.Amount(
                text: title,
                chainTitle: chainTitle,
                style: .positive
            )
        case .negative:
            return MultichainHistoryActivityItem.Amount(
                text: title,
                chainTitle: chainTitle,
                style: .negative
            )
        }
    }

    private func fallbackAmountTitle(
        rawAmount: String,
        symbol: String,
        sign: AmountSign
    ) -> String {
        let signPrefix: String
        switch sign {
        case .positive:
            signPrefix = "+"
        case .negative:
            signPrefix = "\u{2212}"
        }
        return "\(signPrefix)\(rawAmount) \(symbol)"
    }

    private func displaySymbol(
        for token: MultichainAssetDetails,
        displaysNativeTonAsGram: Bool
    ) -> String {
        guard displaysNativeTonAsGram,
              token.chain == .ton,
              case .coin = AssetIdComponents(assetId: token.assetId)
        else {
            return token.symbol
        }
        return TonInfo.symbol
    }

    func unsignedAmount(from value: String) -> BigUInt? {
        var normalized = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\u{2212}", with: "-")

        guard !normalized.isEmpty else {
            return nil
        }

        if normalized.first == "+" || normalized.first == "-" {
            normalized.removeFirst()
        }

        guard normalized.allSatisfy({ "0123456789".contains($0) }) else {
            return nil
        }

        return BigUInt(normalized)
    }

    func timeString(for date: Date) -> String {
        dateFormatter.dateFormat = "HH:mm"
        return dateFormatter.string(from: date)
    }
}
