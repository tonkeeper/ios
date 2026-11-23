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
    private let hidesAmounts: () -> Bool
    private let walletName: String?
    private let decryptedComment: (MultichainActivity) -> String?
    private let decryptComment: ((MultichainActivity) -> Void)?

    /// Only with `decryptComment` does a comment an activity carries encrypted show, until `decryptedComment`
    /// gives it decrypted.
    init(
        amountFormatter: AmountFormatter,
        dateFormatter: DateFormatter,
        transactionButtonProvider: @escaping (MultichainActivity) -> MultichainTransactionDetailsModel.TransactionButton?,
        hidesAmounts: @escaping () -> Bool,
        nftProvider: @escaping (MultichainActivity) -> MultichainActivityNFT? = { _ in nil },
        walletName: String? = nil,
        decryptedComment: @escaping (MultichainActivity) -> String? = { _ in nil },
        decryptComment: ((MultichainActivity) -> Void)? = nil
    ) {
        self.walletName = walletName
        self.decryptedComment = decryptedComment
        self.decryptComment = decryptComment
        self.amountFormatter = amountFormatter
        var signedConfiguration = amountFormatter.config
        signedConfiguration.signPolicy = .always
        self.signedAmountFormatter = AmountFormatter(configuration: signedConfiguration)
        let detailsDateFormatter = dateFormatter.copy() as? DateFormatter ?? DateFormatter()
        detailsDateFormatter.dateFormat = "d MMM, HH:mm"
        self.dateFormatter = detailsDateFormatter
        self.transactionButtonProvider = transactionButtonProvider
        self.nftProvider = nftProvider
        self.hidesAmounts = hidesAmounts
    }

    /// `showsFundingStatus`: a Perps deposit or withdrawal opened while in progress keeps a Status
    /// row that follows it to its outcome. A failed or dropped one always shows it, or nothing would tell the failure.
    func build(activity: MultichainActivity, showsFundingStatus: Bool = false) -> MultichainTransactionDetailsModel {
        let kind = MultichainActivityPresentationKind(activity: activity)
        if let isCredit = kind.isPerpsAccountCredit {
            return perpsFundingModel(activity: activity, kind: kind, isCredit: isCredit, showsStatus: showsFundingStatus)
        }
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
        if let explorerTxId = activity.explorerTxId,
           let separatorIndex = explorerTxId.firstIndex(of: ":")
        {
            let hash = explorerTxId[explorerTxId.index(after: separatorIndex)...]
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !hash.isEmpty { return hash }
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
        // An id on a chain the app does not know, like a Lighter deposit's `lighter:0x…`,
        // is shown by its hash alone.
        let fallbackTransactionID = transactionIDs.lazy.compactMap { transactionID -> String? in
            guard let separatorIndex = transactionID.firstIndex(of: ":") else {
                return transactionID
            }
            guard MultichainChain(assetIdChain: String(transactionID[..<separatorIndex])) == nil else {
                return nil
            }
            let hash = transactionID[transactionID.index(after: separatorIndex)...]
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return hash.isEmpty ? nil : hash
        }.first

        return sourceChainTransactionID ?? fallbackTransactionID
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
            amount: maskedIfHidden(amountTitle(
                activity: activity,
                rawAmount: feeAmount,
                token: feeToken,
                sign: .none,
                style: .compact
            )),
            fiatAmount: hidesAmounts() || activity.isPerpsDollar(feeToken) ? nil : fiatTitle(activity.feeAmountUsd)
        )
    }
}

private extension MultichainTransactionDetailsModelBuilder {
    struct FundingLeg {
        let token: MultichainAssetDetails?
        let rawAmount: String?
        let amountUsd: Double?
        let sign: AmountSign
        let isPerpsBalance: Bool
    }

    /// The Perps balance leg in USDC, and the token on the wallet's side when the backend sends it:
    /// a withdrawal's payout, a deposit's source. They read left to right, outgoing first.
    /// A withdrawal's fee is part of what left the balance: the payout is the amount less the fee.
    func perpsFundingModel(
        activity: MultichainActivity,
        kind: MultichainActivityPresentationKind,
        isCredit: Bool,
        showsStatus: Bool
    ) -> MultichainTransactionDetailsModel {
        let isIncoming = kind.amountSide(for: activity) == .incoming
        let perpsLeg = FundingLeg(
            token: isIncoming ? activity.inToken : activity.outToken,
            rawAmount: isIncoming ? activity.inAmount : activity.outAmount,
            amountUsd: isIncoming ? activity.inAmountUsd : activity.outAmountUsd,
            sign: isCredit ? .positive : .negative,
            isPerpsBalance: true
        )
        let walletToken = isCredit ? activity.outToken : activity.inToken
        let walletLeg = walletToken.flatMap { token -> FundingLeg? in
            let rawAmount = isCredit ? activity.outAmount : activity.inAmount
            let repeatsPerpsLeg = isCredit
                ? activity.isPerpsDollar(token)
                : token.assetId.caseInsensitiveCompare(perpsLeg.token?.assetId ?? "") == .orderedSame
            guard isCredit == isIncoming, rawAmount != nil, !repeatsPerpsLeg else { return nil }
            return FundingLeg(
                token: token,
                rawAmount: rawAmount,
                amountUsd: isCredit ? activity.outAmountUsd : activity.inAmountUsd,
                sign: isCredit ? .negative : .positive,
                isPerpsBalance: false
            )
        }
        let legs = (isCredit ? [walletLeg, perpsLeg] : [perpsLeg, walletLeg]).compactMap { $0 }
        let image: MultichainTransactionDetailsModel.Image = if legs.count == 2 {
            .swap(left: fundingAsset(activity: activity, kind: kind, leg: legs[0]), right: fundingAsset(activity: activity, kind: kind, leg: legs[1]))
        } else {
            .single(fundingAsset(activity: activity, kind: kind, leg: perpsLeg))
        }
        let date = dateString(for: activity.blockTime)

        return MultichainTransactionDetailsModel(
            image: image,
            amountLines: legs.map { fundingAmountLine(activity: activity, leg: $0) },
            fiat: legs.last.flatMap { fundingFiat(activity: activity, leg: $0) }.map(maskedIfHidden),
            date: activity.status == .confirmed
                ? isCredit ? TKLocales.EventDetails.depositedOn(date) : TKLocales.EventDetails.withdrawnOn(date)
                : dateTitle(activity: activity, kind: kind),
            pendingTitle: showsStatus ? nil : pendingTitle(activity: activity, kind: kind),
            rows: [
                walletName.map { .property(title: TKLocales.ConfirmSend.wallet, value: $0) },
                .property(
                    title: isCredit
                        ? TKLocales.MultichainHistory.Perps.depositedTo
                        : TKLocales.MultichainHistory.Perps.withdrawnFrom,
                    value: TKLocales.Perps.balance
                ),
                protocolRow(activity: activity),
                feeRow(activity: activity),
                Self.transactionID(for: activity).map {
                    .inlineHash(title: TKLocales.MultichainHistory.Perps.transactionHash, hash: $0)
                },
                showsStatus || [.failed, .dropped].contains(activity.status) ? fundingStatusRow(activity: activity) : nil,
            ].compactMap { $0 },
            transactionButton: transactionButtonProvider(activity)
        )
    }

    func fundingStatusRow(activity: MultichainActivity) -> MultichainTransactionDetailsCellContent {
        let title = TKLocales.MultichainSwap.Details.status
        switch activity.status {
        case .confirmed:
            return .status(title: title, value: TKLocales.Result.success, color: .accentGreen)
        case .failed:
            return .status(title: title, value: TKLocales.State.failed, color: .accentOrange)
        case .dropped:
            return .status(title: title, value: TKLocales.LiveActivity.dropped, color: .accentOrange)
        case .pending:
            return .status(title: title, value: TKLocales.MultichainSwap.Details.pending, color: .textSecondary, isPending: true)
        }
    }

    func fundingAsset(
        activity: MultichainActivity,
        kind: MultichainActivityPresentationKind,
        leg: FundingLeg
    ) -> MultichainTransactionDetailsModel.Asset {
        guard let token = leg.token,
              !(activity.isPerpsDollar(token) && token.image.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        else {
            return .init(imageSource: .image(kind.icon, chainIcon: nil))
        }
        return asset(token: token, chain: token.chain)
    }

    /// The Perps leg reads in USDC here, not dollars: the dollar value is the line under it.
    /// A withdrawal's payout is compact: the backend sends it with every digit of the token.
    func fundingAmountLine(
        activity: MultichainActivity,
        leg: FundingLeg
    ) -> MultichainTransactionDetailsModel.AmountLine {
        let walletStyle: AmountDisplayStyle = leg.sign == .positive ? .compact : .exactValue
        guard let token = leg.token,
              activity.isPerpsDollar(token),
              let rawAmount = leg.rawAmount,
              let amount = MultichainActivityAmount.unsigned(rawAmount)
        else {
            return amountLine(
                amount: maskedIfHidden(amountTitle(
                    activity: activity,
                    rawAmount: leg.rawAmount,
                    token: leg.token,
                    sign: leg.sign,
                    style: walletStyle
                )),
                chain: amountLineChainTitle(token: leg.token, chain: leg.token?.chain)
            )
        }
        return amountLine(
            amount: maskedIfHidden(signedAmountFormatter.format(
                amount: amount,
                fractionDigits: token.decimals,
                accessory: .tokenSymbol(token.symbol),
                isNegative: leg.sign == .negative,
                style: leg.isPerpsBalance ? .fiatBalance : walletStyle
            )),
            chain: leg.isPerpsBalance ? nil : amountLineChainTitle(token: token, chain: token.chain)
        )
    }

    func fundingFiat(activity: MultichainActivity, leg: FundingLeg) -> String? {
        if let amountUsd = leg.amountUsd {
            let dollars = amountFormatter.format(decimal: Decimal(abs(amountUsd)), accessory: .fiat(Currency.USD), style: .fiatBalance)
            return (leg.sign == .negative ? String.Symbol.minus : String.Symbol.plus) + amountFormatter.config.space + dollars
        }
        guard let token = leg.token, activity.isPerpsDollar(token) else { return nil }
        return amountTitle(activity: activity, rawAmount: leg.rawAmount, token: token, sign: leg.sign, style: .fiatBalance)
    }

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
                activity.toName.map { .property(title: TKLocales.EventDetails.recipient, value: $0) },
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
                activity.fromName.map { .property(title: TKLocales.EventDetails.sender, value: $0) },
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
                    amount: maskedIfHidden(amountTitle(
                        activity: activity,
                        rawAmount: activity.outAmount,
                        token: outToken,
                        sign: .negative
                    )),
                    chain: amountLineChainTitle(token: outToken, chain: fromChain)
                ),
                amountLine(
                    amount: maskedIfHidden(amountTitle(
                        activity: activity,
                        rawAmount: activity.inAmount,
                        token: inToken,
                        sign: .positive
                    )),
                    chain: amountLineChainTitle(token: inToken, chain: toChain)
                ),
            ],
            fiat: fiatTitle(activity.inAmountUsd ?? activity.outAmountUsd).map(maskedIfHidden),
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
        sign: AmountSign,
        style: AmountDisplayStyle = .exactValue
    ) -> Hero {
        if let nft = nftProvider(activity) {
            return Hero(
                image: .nft(
                    MultichainTransactionDetailsModel.Asset(
                        imageSource: .url(nft.imageURL)
                    ),
                    isSecureMode: hidesAmounts()
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

        // A dollar amount already is its own fiat value.
        let isDollar = token.map(activity.isPerpsDollar) ?? false
        return Hero(
            image: .single(asset(token: token, chain: chain)),
            nft: nil,
            amountLines: [
                amountLine(
                    amount: maskedIfHidden(amountTitle(
                        activity: activity,
                        rawAmount: rawAmount,
                        token: token,
                        sign: sign,
                        style: style
                    )),
                    chain: isDollar ? nil : amountLineChainTitle(token: token, chain: chain)
                ),
            ],
            fiat: isDollar ? nil : fiatTitle(amountUsd).map(maskedIfHidden)
        )
    }

    func maskedIfHidden(_ text: String) -> String {
        hidesAmounts() ? .secureModeValueShort : text
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
        guard !activity.isSpam else {
            return nil
        }
        if let comment = activity.comment {
            return commentRow(comment)
        }
        guard let encryptedComment = activity.encryptedComment, let decryptComment else {
            return nil
        }
        // Secure mode hides what it decrypted to, as TON history does.
        if !hidesAmounts(), let comment = decryptedComment(activity) {
            return commentRow(comment)
        }
        return .encryptedComment(
            title: TKLocales.EventDetails.comment,
            length: encryptedComment.approximateLength,
            decrypt: { decryptComment(activity) }
        )
    }

    func commentRow(_ comment: String) -> MultichainTransactionDetailsCellContent? {
        let trimmedComment = comment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedComment.isEmpty else {
            return nil
        }
        return .comment(
            title: TKLocales.EventDetails.comment,
            value: trimmedComment
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
        let displayName = activity.activityType.isPerps && protocolName.lowercased() == "lighter"
            ? "Lighter" : MultichainHistoryStakingProvider(rawValue: protocolName)?.displayName ?? protocolName
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
        activity: MultichainActivity,
        rawAmount: String?,
        token: MultichainAssetDetails?,
        sign: AmountSign,
        style: AmountDisplayStyle = .exactValue
    ) -> String {
        guard let rawAmount, let token else {
            return "-"
        }

        let symbol = displaySymbol(for: token, activity: activity)
        if let amount = MultichainActivityAmount.unsigned(rawAmount) {
            if activity.isPerpsDollar(token) {
                return sign == .none
                    ? amountFormatter.format(
                        amount: amount,
                        fractionDigits: token.decimals,
                        accessory: .fiat(Currency.USD),
                        style: style
                    )
                    : amountFormatter.signedDollars(
                        amount: amount,
                        fractionDigits: token.decimals,
                        isNegative: sign == .negative,
                        style: style
                    )
            }
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

    func displaySymbol(for token: MultichainAssetDetails, activity: MultichainActivity) -> String {
        guard token.chain == .ton,
              case .coin = AssetIdComponents(assetId: token.assetId)
        else {
            return activity.displaySymbol(for: token)
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
        if kind.isPerpsAccountCredit != nil {
            return "\(kind.title) · \(date)"
        }
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

extension MultichainActivity {
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
