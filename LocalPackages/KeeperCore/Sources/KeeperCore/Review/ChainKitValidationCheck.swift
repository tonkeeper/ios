@preconcurrency import BigInt
@preconcurrency import ChainKit
import OperationReviewModels
import TKLocalize

/// chain-kit's validation of what is signed against what the user agreed to.
struct ChainKitValidationCheck: OperationCheck {
    let client: CryptoKitClient

    func findings(of signable: SignableOperation) async throws -> [OperationFinding] {
        let intent = try Self.intent(of: signable)
        let result = try await client.blockchain.getMediator(network: signable.account.chain.network.type).operation.validate(
            operation: signable.operation,
            account: signable.account,
            intent: intent
        )
        return Self.findings(result.findings, of: signable, intent: intent)
    }
}

extension ChainKitValidationCheck {
    /// What the user agreed to, as chain-kit reads it.
    static func intent(of signable: SignableOperation) throws -> ChainKit.Intent {
        let chain = signable.account.chain
        let spends = try signable.intent.spends.map { perAsset($0 + unstatedRelayerFee(of: signable)) }?.map { spend in
            guard let decimals = Int32(exactly: spend.decimals),
                  let asset = AssetCompanion.shared.fromString(
                      assetId: spend.assetId,
                      name: spend.symbol,
                      symbol: spend.symbol,
                      decimals: decimals
                  )
            else {
                throw ChainKitOperationError.malformed("spent asset \(spend.assetId)")
            }
            return ChainKit.Intent.Spend(
                asset: asset,
                amount: BignumBigInteger.Companion.shared.parseString(string: spend.amount.description, base: 10)
            )
        }
        let recipient = try signable.intent.recipient.map { recipient in
            guard let address = Address.Companion.shared.from(value: recipient, chain: chain, type: .default_) else {
                throw ChainKitOperationError.malformed("\(chain.name) recipient")
            }
            return address
        }
        return ChainKit.Intent(spends: spends, to: recipient, source: signable.intent.isDapp ? .dapp : .wallet)
    }

    /// The relayer's fee as one more spend, where no payload states a fee. chain-kit lets a fee a
    /// payload states be paid from inside it up to twice that quote, to anyone but the recipient: a
    /// spend beside it would only widen what else the operation may take.
    private static func unstatedRelayerFee(of signable: SignableOperation) -> [OperationIntent.Spend] {
        guard let fee = signable.intent.relayerFee, !signable.operation.payloads.contains(where: { $0.fee != nil }) else {
            return []
        }
        return [fee]
    }

    /// One spend per asset: chain-kit holds what is taken of a token to the spends of an equal asset,
    /// and two assets it builds from one id are never equal (its `Decimal` compares by identity), so
    /// a relayer's fee listed beside the amount in the same token would be left out of its limit.
    private static func perAsset(_ spends: [OperationIntent.Spend]) -> [OperationIntent.Spend] {
        spends.reduce(into: []) { summed, spend in
            guard let index = summed.firstIndex(where: {
                AssetIdComponents.isSameAsset($0.assetId, spend.assetId) && $0.decimals == spend.decimals
            }) else {
                summed.append(spend)
                return
            }
            let first = summed[index]
            summed[index] = OperationIntent.Spend(assetId: first.assetId, symbol: first.symbol, decimals: first.decimals, amount: first.amount + spend.amount)
        }
    }

    /// Every finding, its id the operation's and its place there, so that the findings of the
    /// operations one review reads stay apart. One that says its validator threw, or that the chain
    /// has none, carries why as its failure, which the gate logs as the flow's.
    static func findings(_ errors: [ValidationError], of signable: SignableOperation, intent: ChainKit.Intent) -> [OperationFinding] {
        errors.enumerated().map { index, error in
            OperationFinding(
                id: "\(signable.operation.id):\(index)",
                kind: "\(type(of: error))",
                severity: severity(of: error, within: intent.source),
                title: title(of: error),
                details: details(of: error, in: intent),
                subject: subject(of: error),
                failure: error is ValidationError.Unknown || error is ValidationError.UnsupportedChain ? String(describing: error) : nil
            )
        }
    }

    /// Rated by the class of the finding, as Android rates it: one that does more than was agreed is
    /// a danger, and so are wrong decimals, which show another amount than the one signed. In a flow
    /// of the wallet's own the backend built what is signed, so what the validator cannot read or
    /// finds odd there is not the user's to judge.
    static func severity(of error: ValidationError, within source: ChainKit.Intent.Source) -> OperationFinding.Severity {
        if error is ValidationError.Dangerous || error is ValidationError.WrongDecimals {
            return .danger
        }
        if error is ValidationError.Info || source == .wallet {
            return .info
        }
        return .warning
    }

    private static func title(of error: ValidationError) -> String {
        switch error {
        case is ValidationError.Overspend: TKLocales.OperationValidation.Finding.overspend
        case is ValidationError.ForeignRecipient: TKLocales.OperationValidation.Finding.foreignRecipient
        case is ValidationError.ForeignAsset: TKLocales.OperationValidation.Finding.foreignAsset
        case is ValidationError.CollectionApproval: TKLocales.OperationValidation.Finding.collectionApproval
        case is ValidationError.ForeignDelegate: TKLocales.OperationValidation.Finding.foreignDelegate
        case is ValidationError.PermissionUpdate: TKLocales.OperationValidation.Finding.permissionUpdate
        case is ValidationError.PermissionShared: TKLocales.OperationValidation.Finding.permissionShared
        case is ValidationError.ForeignChain: TKLocales.OperationValidation.Finding.foreignChain
        case is ValidationError.ForeignAccount: TKLocales.OperationValidation.Finding.foreignAccount
        case is ValidationError.ForeignOrigin: TKLocales.OperationValidation.Finding.foreignOrigin
        case is ValidationError.SelfAuthorization: TKLocales.OperationValidation.Finding.selfAuthorization
        case is ValidationError.LooseSighash: TKLocales.OperationValidation.Finding.looseSighash
        case is ValidationError.AuthorityChange: TKLocales.OperationValidation.Finding.authorityChange
        case is ValidationError.TransactionAsMessage: TKLocales.OperationValidation.Finding.transactionAsMessage
        case is ValidationError.AccountDestruction: TKLocales.OperationValidation.Finding.accountDestruction
        case is ValidationError.BlindSignature: TKLocales.OperationValidation.Finding.blindSignature
        case is ValidationError.ForeignStateInit: TKLocales.OperationValidation.Finding.foreignStateInit
        case is ValidationError.Malformed: TKLocales.OperationValidation.Finding.malformed
        case is ValidationError.UnknownScript: TKLocales.OperationValidation.Finding.unknownScript
        case is ValidationError.WholeBalance: TKLocales.OperationValidation.Finding.wholeBalance
        case is ValidationError.ReceiverData: TKLocales.OperationValidation.Finding.receiverData
        case is ValidationError.SelfCall: TKLocales.OperationValidation.Finding.selfCall
        case is ValidationError.UnknownDocument: TKLocales.OperationValidation.Finding.unknownDocument
        case is ValidationError.OpaqueMessage: TKLocales.OperationValidation.Finding.opaqueMessage
        case is ValidationError.UnresolvedAccount: TKLocales.OperationValidation.Finding.unresolvedAccount
        case is ValidationError.UnsupportedAsset: TKLocales.OperationValidation.Finding.unsupportedAsset
        case is ValidationError.UnsupportedPayload: TKLocales.OperationValidation.Finding.unsupportedPayload
        case is ValidationError.LongAllowance: TKLocales.OperationValidation.Finding.longAllowance
        case is ValidationError.DurableNonce: TKLocales.OperationValidation.Finding.durableNonce
        case is ValidationError.SingleSighash: TKLocales.OperationValidation.Finding.singleSighash
        case is ValidationError.UnlistedAsset: TKLocales.OperationValidation.Finding.unlistedAsset
        case is ValidationError.LargeApproval: TKLocales.OperationValidation.Finding.largeApproval
        case is ValidationError.BlindCall: TKLocales.OperationValidation.Finding.blindCall
        case is ValidationError.ForeignOwner: TKLocales.OperationValidation.Finding.foreignOwner
        case is ValidationError.MarketplaceApproval: TKLocales.OperationValidation.Finding.marketplaceApproval
        case is ValidationError.Approval: TKLocales.OperationValidation.Finding.approval
        case is ValidationError.WrongDecimals: TKLocales.OperationValidation.Finding.wrongDecimals
        case is ValidationError.UnsupportedChain: TKLocales.OperationValidation.Finding.unsupportedChain
        default: TKLocales.OperationValidation.Finding.unknown
        }
    }

    /// Who or what the finding is about, as its chain names it.
    private static func subject(of error: ValidationError) -> String? {
        switch error {
        case let error as ValidationError.Overspend: error.asset
        case let error as ValidationError.ForeignRecipient: error.actual
        case let error as ValidationError.ForeignAsset: error.asset
        case let error as ValidationError.CollectionApproval: error.operator_
        case let error as ValidationError.ForeignDelegate: error.implementation
        case let error as ValidationError.PermissionUpdate: error.keys.joined(separator: ", ")
        case let error as ValidationError.PermissionShared: error.keys.joined(separator: ", ")
        case let error as ValidationError.ForeignChain: error.actual
        case let error as ValidationError.ForeignAccount: error.actual
        case let error as ValidationError.ForeignOrigin: error.actual
        case let error as ValidationError.AuthorityChange: error.authority
        case let error as ValidationError.ForeignStateInit: error.destination
        case let error as ValidationError.Malformed: error.part
        case let error as ValidationError.WholeBalance: error.target
        case let error as ValidationError.UnknownDocument: error.part
        case let error as ValidationError.UnresolvedAccount: error.account
        case let error as ValidationError.UnsupportedAsset: error.asset
        case let error as ValidationError.UnsupportedPayload: error.type
        case let error as ValidationError.LongAllowance: error.spender
        case let error as ValidationError.UnlistedAsset: error.asset
        case let error as ValidationError.LargeApproval: error.spender
        case let error as ValidationError.BlindCall: error.target
        case let error as ValidationError.ForeignOwner: error.owner
        case let error as ValidationError.MarketplaceApproval: error.operator_
        case let error as ValidationError.Approval: error.spender
        case let error as ValidationError.WrongDecimals: error.asset
        case let error as ValidationError.UnsupportedChain: error.chain
        default: nil
        }
    }

    /// What the finding moves or allows, against what the screen showed, in the asset of the intent
    /// it names. A finding names it as its chain does, by id or by contract; an asset the intent does
    /// not list has no decimals to show the amount in.
    private static func details(of error: ValidationError, in intent: ChainKit.Intent) -> String? {
        let named: String
        switch error {
        case let error as ValidationError.Overspend: named = error.asset
        case let error as ValidationError.LargeApproval: named = error.asset
        case let error as ValidationError.Approval: named = error.asset
        case let error as ValidationError.LongAllowance: named = error.token
        default: return nil
        }
        guard let asset = intent.listed.map(\.asset).first(where: {
            $0.id == named || ($0 as? AssetToken)?.contract.display.caseInsensitiveCompare(named) == .orderedSame
        }) else {
            return nil
        }
        let formatter = AmountFormatter()
        func format(_ amount: BignumBigInteger) -> String {
            if amount.isUnlimited {
                return TKLocales.OperationValidation.unlimited(asset.symbol)
            }
            guard let units = BigUInt(amount.description) else {
                return "\(amount.description) \(asset.symbol)"
            }
            return formatter.format(amount: units, fractionDigits: Int(asset.decimals.value), accessory: .tokenSymbol(asset.symbol), style: .exactValue)
        }
        switch error {
        case let error as ValidationError.Overspend:
            return TKLocales.OperationValidation.amountInstead(format(error.actual), format(error.limit))
        case let error as ValidationError.LargeApproval:
            return error.limit.map { TKLocales.OperationValidation.amountInstead(format(error.amount), format($0)) } ?? format(error.amount)
        case let error as ValidationError.Approval:
            return format(error.amount)
        case let error as ValidationError.LongAllowance:
            return format(error.amount)
        default:
            return nil
        }
    }
}
