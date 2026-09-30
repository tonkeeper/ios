import AppUI
import BigInt
import Foundation
import KeeperCore
import TKLocalize
import TKUIKit

struct MultichainTransactionDetailsModelBuilder {
    private let amountFormatter: AmountFormatter
    private let signedAmountFormatter: AmountFormatter
    private let dateFormatter: DateFormatter
    private let transactionButtonProvider: (MultichainActivity) -> MultichainTransactionDetailsModel.TransactionButton?
    private let nftProvider: (MultichainActivity) -> MultichainActivityNFT?

    init(
        amountFormatter: AmountFormatter,
        dateFormatter: DateFormatter,
        transactionButtonProvider: @escaping (MultichainActivity) -> MultichainTransactionDetailsModel.TransactionButton?,
        nftProvider: @escaping (MultichainActivity) -> MultichainActivityNFT? = { _ in nil }
    ) {
        self.amountFormatter = amountFormatter
        var signedConfiguration = amountFormatter.config
        signedConfiguration.signPolicy = .always
        self.signedAmountFormatter = AmountFormatter(configuration: signedConfiguration)
        let detailsDateFormatter = dateFormatter.copy() as? DateFormatter ?? DateFormatter()
        detailsDateFormatter.dateFormat = "d MMM, HH:mm"
        self.dateFormatter = detailsDateFormatter
        self.transactionButtonProvider = transactionButtonProvider
        self.nftProvider = nftProvider
    }

    func build(activity: MultichainActivity) -> MultichainTransactionDetailsModel {
        let kind = MultichainActivityPresentationKind(activity: activity)
        // A pending exchange knows both tokens but not yet both amounts, so the amount side alone
        // would collapse it to a single leg.
        if activity.rendersTokenPair {
            return swapModel(activity: activity, kind: kind)
        }
        switch kind.amountSide(for: activity) {
        case .outgoing:
            return sentModel(activity: activity, kind: kind)
        case .incoming:
            return receivedModel(activity: activity, kind: kind)
        case .both:
            return swapModel(activity: activity, kind: kind)
        }
    }

    static func transactionButton(
        for activity: MultichainActivity
    ) -> MultichainTransactionDetailsModel.TransactionButton? {
        guard let url = activity.explorerURL,
              let scheme = url.scheme?.lowercased(),
              scheme == "https" || scheme == "http",
              let transactionID = transactionID(for: activity)
        else {
            return nil
        }

        return MultichainTransactionDetailsModel.TransactionButton(
            title: TKThemedText(spans: [
                .init(TKLocales.EventDetails.transaction, color: .textPrimary),
                .init(String(transactionID.prefix(8)), color: .textSecondary),
            ]),
            url: url,
            browserTitle: nil
        )
    }

    private static func transactionID(for activity: MultichainActivity) -> String? {
        let transactionIDs = activity.txIds.compactMap { rawTransactionID -> String? in
            let transactionID = rawTransactionID.trimmingCharacters(in: .whitespacesAndNewlines)
            return transactionID.isEmpty ? nil : transactionID
        }
        let sourceChainTransactionID = transactionIDs.compactMap { transactionID -> String? in
            guard let separatorIndex = transactionID.firstIndex(of: ":"),
                  MultichainChain(
                      assetIdChain: String(transactionID[..<separatorIndex])
                  ) == activity.fromChain
            else {
                return nil
            }

            let transactionID = String(transactionID[transactionID.index(after: separatorIndex)...])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return transactionID.isEmpty ? nil : transactionID
        }.first
        let fallbackTransactionID = transactionIDs.first { transactionID in
            guard let separatorIndex = transactionID.firstIndex(of: ":") else {
                return true
            }
            return MultichainChain(
                assetIdChain: String(transactionID[..<separatorIndex])
            ) == nil
        }

        return sourceChainTransactionID ?? fallbackTransactionID
    }
}

private extension MultichainTransactionDetailsModelBuilder {
    func sentModel(
        activity: MultichainActivity,
        kind: MultichainActivityPresentationKind
    ) -> MultichainTransactionDetailsModel {
        let token = activity.outToken
        let chain = token?.chain ?? activity.fromChain
        let hero = hero(
            activity: activity,
            kind: kind,
            token: token,
            chain: chain,
            rawAmount: activity.outAmount,
            amountUsd: activity.outAmountUsd,
            sign: .negative
        )

        return MultichainTransactionDetailsModel(
            image: hero.image,
            nft: hero.nft,
            amountLines: hero.amountLines,
            fiat: hero.fiat,
            date: dateTitle(activity: activity, kind: kind),
            pendingTitle: pendingTitle(activity: activity, kind: kind),
            rows: [
                addressRow(
                    type: TKLocales.EventDetails.recipientAddress,
                    value: activity.toAddress ?? activity.walletAddress,
                    chain: activity.toChain
                ),
                commentRow(activity: activity),
                networkRow(
                    fromChain: activity.fromChain,
                    toChain: activity.toChain
                ),
                feeRow(activity: activity),
                txHashRow(activity: activity),
                protocolRow(activity: activity),
            ].compactMap { $0 },
            transactionButton: transactionButtonProvider(activity)
        )
    }

    func receivedModel(
        activity: MultichainActivity,
        kind: MultichainActivityPresentationKind
    ) -> MultichainTransactionDetailsModel {
        let token = activity.inToken
        let chain = token?.chain ?? activity.toChain
        let hero = hero(
            activity: activity,
            kind: kind,
            token: token,
            chain: chain,
            rawAmount: activity.inAmount,
            amountUsd: activity.inAmountUsd,
            sign: .positive
        )

        return MultichainTransactionDetailsModel(
            image: hero.image,
            nft: hero.nft,
            amountLines: hero.amountLines,
            fiat: hero.fiat,
            date: dateTitle(activity: activity, kind: kind),
            pendingTitle: pendingTitle(activity: activity, kind: kind),
            rows: [
                addressRow(
                    type: TKLocales.EventDetails.senderAddress,
                    value: activity.fromAddress ?? activity.walletAddress,
                    chain: activity.fromChain
                ),
                commentRow(activity: activity),
                networkRow(
                    fromChain: activity.fromChain,
                    toChain: activity.toChain
                ),
                feeRow(activity: activity),
                txHashRow(activity: activity),
                protocolRow(activity: activity),
            ].compactMap { $0 },
            transactionButton: transactionButtonProvider(activity)
        )
    }

    func swapModel(
        activity: MultichainActivity,
        kind: MultichainActivityPresentationKind
    ) -> MultichainTransactionDetailsModel {
        let outToken = activity.outToken
        let inToken = activity.inToken
        let fromChain = outToken?.chain ?? activity.fromChain
        let toChain = inToken?.chain ?? activity.toChain

        return MultichainTransactionDetailsModel(
            image: .swap(
                left: asset(token: outToken, chain: fromChain),
                right: asset(token: inToken, chain: toChain)
            ),
            amountLines: [
                amountLine(
                    amount: amountTitle(
                        rawAmount: activity.outAmount,
                        token: outToken,
                        sign: .negative
                    ),
                    chain: amountLineChainTitle(token: outToken, chain: fromChain)
                ),
                amountLine(
                    amount: amountTitle(
                        rawAmount: activity.inAmount,
                        token: inToken,
                        sign: .positive
                    ),
                    chain: amountLineChainTitle(token: inToken, chain: toChain)
                ),
            ],
            fiat: fiatTitle(activity.inAmountUsd ?? activity.outAmountUsd),
            date: dateTitle(activity: activity, kind: kind),
            pendingTitle: pendingTitle(activity: activity, kind: kind),
            rows: [
                addressRow(
                    type: TKLocales.EventDetails.recipient,
                    value: activity.toAddress ?? activity.walletAddress,
                    chain: activity.toChain
                ),
                commentRow(activity: activity),
                networkRow(
                    fromChain: activity.fromChain,
                    toChain: activity.toChain
                ),
                feeRow(activity: activity),
                txHashRow(activity: activity),
                protocolRow(activity: activity),
            ].compactMap { $0 },
            transactionButton: transactionButtonProvider(activity)
        )
    }

    struct Hero {
        let image: MultichainTransactionDetailsModel.Image
        let nft: MultichainTransactionDetailsModel.NFT?
        let amountLines: [MultichainTransactionDetailsModel.AmountLine]
        let fiat: String?
    }

    func hero(
        activity: MultichainActivity,
        kind: MultichainActivityPresentationKind,
        token: MultichainAssetDetails?,
        chain: MultichainChain?,
        rawAmount: String?,
        amountUsd: Double?,
        sign: AmountSign
    ) -> Hero {
        if let nft = nftProvider(activity) {
            return Hero(
                image: .nft(
                    MultichainTransactionDetailsModel.Asset(
                        imageSource: .url(nft.imageURL)
                    )
                ),
                nft: MultichainTransactionDetailsModel.NFT(
                    name: nft.name,
                    collectionName: nft.collectionName,
                    isVerified: nft.isVerified
                ),
                amountLines: [
                    amountLine(
                        amount: MultichainActivityNFT.amountTitle,
                        chain: nil
                    ),
                ],
                fiat: nil
            )
        }

        // A renewal transfers nothing, so the renewed domain headlines the screen in place of
        // an amount, and the protocol row that carries it is dropped rather than repeated.
        if kind == .dnsRenew {
            return Hero(
                image: .single(asset(token: token, chain: chain)),
                nft: nil,
                amountLines: [amountLine(amount: renewedDomain(activity: activity) ?? kind.title, chain: nil)],
                fiat: nil
            )
        }

        return Hero(
            image: .single(asset(token: token, chain: chain)),
            nft: nil,
            amountLines: [
                amountLine(
                    amount: amountTitle(
                        rawAmount: rawAmount,
                        token: token,
                        sign: sign
                    ),
                    chain: amountLineChainTitle(token: token, chain: chain)
                ),
            ],
            fiat: fiatTitle(amountUsd)
        )
    }

    func asset(
        token: MultichainAssetDetails?,
        chain: MultichainChain?
    ) -> MultichainTransactionDetailsModel.Asset {
        guard let token else {
            return MultichainTransactionDetailsModel.Asset(
                imageSource: .url(nil, chainIcon: chain?.addressConfiguration.icon)
            )
        }

        return MultichainTransactionDetailsModel.Asset(
            imageSource: AssetIdResolver.imageSource(
                for: token.assetId,
                imageUrl: URL(string: token.image),
                multichainEnabled: true
            )
        )
    }

    func addressRow(
        type: String,
        value: String?,
        chain: MultichainChain?
    ) -> MultichainTransactionDetailsCellContent? {
        guard let value, !value.isEmpty, let chain else {
            return nil
        }
        return .address(
            type: type,
            address: MultichainAddressFormatter.fullAddress(
                value,
                chain: chain
            )
        )
    }

    func networkRow(
        fromChain: MultichainChain?,
        toChain: MultichainChain?
    ) -> MultichainTransactionDetailsCellContent? {
        guard let fromChain else {
            return nil
        }
        if let toChain, toChain != fromChain {
            return .network(
                title: TKLocales.Ramp.Deposit.network,
                name: networkValue(
                    from: fromChain.title,
                    to: toChain.title
                ),
                type: "\(fromChain.symbol) \(String.arrow) \(toChain.symbol)"
            )
        } else {
            return .network(
                title: TKLocales.Ramp.Deposit.network,
                name: TKThemedText(fromChain.title, color: .textPrimary),
                type: fromChain.tokenType
            )
        }
    }

    func commentRow(activity: MultichainActivity) -> MultichainTransactionDetailsCellContent? {
        guard !activity.isSpam,
              let comment = activity.comment?.trimmingCharacters(in: .whitespacesAndNewlines),
              !comment.isEmpty
        else {
            return nil
        }
        return .comment(
            title: TKLocales.EventDetails.comment,
            value: comment
        )
    }

    func feeRow(activity: MultichainActivity) -> MultichainTransactionDetailsCellContent? {
        if let batteryFee = batteryFeeRow(activity: activity) {
            return batteryFee
        }
        if let tronResourceFee = tronResourceFeeRow(activity: activity) {
            return tronResourceFee
        }
        guard let feeAmount = activity.feeAmount,
              let feeToken = activity.feeToken
        else {
            return nil
        }
        return .fee(
            title: TKLocales.FeeMethodPicker.title,
            amount: amountTitle(
                rawAmount: feeAmount,
                token: feeToken,
                sign: .none,
                style: .compact
            ),
            fiatAmount: fiatTitle(activity.feeAmountUsd)
        )
    }

    /// A Battery-paid fee is what the user spent, regardless of the TRX the relayer burned on-chain.
    func batteryFeeRow(activity: MultichainActivity) -> MultichainTransactionDetailsCellContent? {
        guard activity.direction != .incoming,
              let charges = activity.batteryCharges
        else {
            return nil
        }
        return .fee(
            title: TKLocales.FeeMethodPicker.title,
            amount: "\(charges) \(TKLocales.Battery.Refill.chargesCount(count: charges))",
            fiatAmount: nil
        )
    }

    /// Fallback for sponsored TRON transfers that burn no TRX and carry no charge count: the backend
    /// exposes consumed Energy/Bandwidth in `meta.tron_resource` instead of a unit fee amount.
    func tronResourceFeeRow(activity: MultichainActivity) -> MultichainTransactionDetailsCellContent? {
        guard activity.direction != .incoming,
              let resource = activity.tronResource,
              !hasNonZeroUnitFee(activity)
        else {
            return nil
        }
        let energyText = resource.energy > 0
            ? TKLocales.EventDetails.tronResourceEnergy(Self.formatGrouped(resource.energy))
            : nil
        let bandwidthText = resource.bandwidth > 0
            ? TKLocales.EventDetails.tronResourceBandwidth(Self.formatGrouped(resource.bandwidth))
            : nil
        // Reuses the fee cell's secondary line (`fiatAmount`) for Bandwidth — not a fiat string.
        let parts = [energyText, bandwidthText].compactMap { $0 }
        guard let first = parts.first else {
            return nil
        }
        return .fee(
            title: TKLocales.FeeMethodPicker.title,
            amount: first,
            fiatAmount: parts.dropFirst().first
        )
    }

    func hasNonZeroUnitFee(_ activity: MultichainActivity) -> Bool {
        guard let feeAmount = activity.feeAmount,
              let amount = BigInt(feeAmount)
        else {
            return false
        }
        return amount != 0
    }

    static func formatGrouped(_ value: Int64) -> String {
        groupedNumberFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private static let groupedNumberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = .current
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = true
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    func txHashRow(activity: MultichainActivity) -> MultichainTransactionDetailsCellContent? {
        guard let transactionID = Self.transactionID(for: activity) else {
            return nil
        }
        return .txHash(
            title: TKLocales.EventDetails.txHash,
            hash: transactionID
        )
    }

    func renewedDomain(activity: MultichainActivity) -> String? {
        guard let domain = activity.protocolName?.trimmingCharacters(in: .whitespacesAndNewlines),
              !domain.isEmpty
        else {
            return nil
        }
        return domain
    }

    func protocolRow(activity: MultichainActivity) -> MultichainTransactionDetailsCellContent? {
        guard MultichainActivityPresentationKind(activity: activity) != .dnsRenew else {
            return nil
        }
        guard let protocolName = activity.protocolName?.trimmingCharacters(in: .whitespacesAndNewlines),
              !protocolName.isEmpty
        else {
            return nil
        }
        let displayName = MultichainHistoryStakingProvider(rawValue: protocolName)?.displayName ?? protocolName
        return .property(
            title: TKLocales.EventDetails.protocol,
            value: displayName
        )
    }

    enum AmountSign {
        case positive
        case negative
        case none
    }

    func amountTitle(
        rawAmount: String?,
        token: MultichainAssetDetails?,
        sign: AmountSign,
        style: AmountDisplayStyle = .exactValue
    ) -> String {
        guard let rawAmount, let token else {
            return "-"
        }

        let symbol = displaySymbol(for: token)
        if let amount = unsignedAmount(from: rawAmount) {
            switch sign {
            case .positive:
                return signedAmountFormatter.format(
                    amount: amount,
                    fractionDigits: token.decimals,
                    accessory: .tokenSymbol(symbol),
                    isNegative: false,
                    style: style
                )
            case .negative:
                return signedAmountFormatter.format(
                    amount: amount,
                    fractionDigits: token.decimals,
                    accessory: .tokenSymbol(symbol),
                    isNegative: true,
                    style: style
                )
            case .none:
                return amountFormatter.format(
                    amount: amount,
                    fractionDigits: token.decimals,
                    accessory: .tokenSymbol(symbol),
                    style: style
                )
            }
        }

        let prefix: String
        switch sign {
        case .positive:
            prefix = "+"
        case .negative:
            prefix = String.Symbol.minus
        case .none:
            prefix = ""
        }
        return "\(prefix)\(rawAmount) \(symbol)"
    }

    func displaySymbol(for token: MultichainAssetDetails) -> String {
        guard token.chain == .ton,
              case .coin = AssetIdComponents(assetId: token.assetId)
        else {
            return token.symbol
        }
        return TonInfo.symbol
    }

    func fiatTitle(_ value: Double?) -> String? {
        guard let value else {
            return nil
        }

        return amountFormatter.format(
            decimal: Decimal(value),
            accessory: .fiat(Currency.USD),
            style: .regular
        )
    }

    func dateTitle(
        activity: MultichainActivity,
        kind: MultichainActivityPresentationKind
    ) -> String {
        let date = dateString(for: activity.blockTime)
        // A bridge maps to a send/receive kind, so its own date title would describe a transfer
        // while the screen above it shows both legs of an exchange.
        guard activity.rendersTokenPair else {
            return kind.detailsDateTitle(date: date)
        }
        // A pending exchange has not swapped anything yet, so "Swapped on" would claim too much;
        // the pending status line below carries the progress instead.
        return activity.status == .pending
            ? date
            : MultichainActivityPresentationKind.swap.detailsDateTitle(date: date)
    }

    func pendingTitle(
        activity: MultichainActivity,
        kind: MultichainActivityPresentationKind
    ) -> String? {
        guard activity.status == .pending else {
            return nil
        }
        return activity.rendersTokenPair
            ? MultichainActivityPresentationKind.swap.pendingTitle
            : kind.pendingTitle
    }

    func dateString(for date: Date) -> String {
        return dateFormatter.string(from: date)
    }

    func unsignedAmount(from value: String) -> BigUInt? {
        var normalized = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: String.Symbol.minus, with: "-")

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

    func networkValue(from: String, to: String) -> TKThemedText {
        TKThemedText(spans: [
            .init("\(from) ", color: .textPrimary),
            .init("\(String.arrow) ", color: .textSecondary),
            .init(to, color: .textPrimary),
        ])
    }

    func amountLine(
        amount: String,
        chain: String?
    ) -> MultichainTransactionDetailsModel.AmountLine {
        return MultichainTransactionDetailsModel.AmountLine(
            amount: amount,
            chain: chain
        )
    }

    func amountLineChainTitle(
        token: MultichainAssetDetails?,
        chain: MultichainChain?
    ) -> String? {
        guard let token,
              let assetIdComponents = AssetIdComponents(assetId: token.assetId)
        else {
            return chain?.title
        }

        switch assetIdComponents {
        case .coin:
            return nil
        case .asset:
            return chain?.title
        }
    }
}

private extension MultichainActivity {
    /// A same-chain swap and a cross-chain bridge both exchange one token for another, and the
    /// multichain swap flow reports either one depending on whether the chains match.
    var isExchange: Bool {
        switch activityType {
        case .swap, .bridge:
            return true
        default:
            return false
        }
    }

    var rendersTokenPair: Bool {
        isExchange && outToken != nil && inToken != nil
    }
}

private extension MultichainChain {
    var title: String {
        addressConfiguration.title
    }
}

private extension String {
    static let arrow = "\u{2192}"
}
