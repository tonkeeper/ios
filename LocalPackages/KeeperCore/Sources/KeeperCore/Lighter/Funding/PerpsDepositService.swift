import BigInt
import Foundation
import OpenAPIRuntime
import OperationReviewModels
import PerpsModels
import TKLogging
import TKPerpsAPI

enum PerpsDepositServiceError: Error, Equatable {
    case paymentInProgress
    case quoteExpired(String)
    /// An approval for a source that is not a token: nothing to approve, and the payload
    /// would be spending something this client cannot read.
    case approvalWithoutToken(String)
    /// The review promised to finish this payment, and it is no longer the one
    /// the journal holds: registered meanwhile, or replaced by another.
    case resumedPaymentChanged(String)
    case registrationRejected(String)
    /// The backend would not record the deposit while another one creates the account, and
    /// it was not broadcast.
    case accountCreationPending
    /// The quote signed for the key registration credits less than the preview confirmed.
    case registrationRepriced(quoted: String, previewed: String)
    /// The node refused the payment: the coin the fee is paid in does not cover it.
    case insufficientNetworkFee(symbol: String)
    case networkFeeUnavailable
    /// The relayed fee method confirmed for this payment can no longer carry it.
    case relayUnavailable
    case bitcoinFeeRaised(quoted: String, shown: String)
}

/// What the confirmation states, and what the payment is then bound to. The quote inside
/// it is the one that was checked — `pay` never re-reads the terms from anywhere else.
public struct PerpsDepositReview: Sendable, Equatable {
    enum Payment: Sendable, Equatable {
        case quoted(PerpsDepositQuote)
        /// Registers the key on the account: paying signs the preview and
        /// asks for the quote it sends.
        case registering(PerpsKeyRegistrationPreview)
        /// Sent earlier without a registration on record: paying again only records it.
        case resuming(operationId: String)
    }

    public let sourceAsset: PerpsFundingAsset
    public let sourceChain: MultichainChain
    /// The same amount as the screen spelled it, so display never re-derives it from a
    /// Double.
    public let sourceAmount: String
    /// USDC credited to the Lighter account, exactly (`expected == min` by contract).
    public let creditedAmount: String
    /// The chain's own coin, as it is spelled for display. Absent when a payload cannot be
    /// priced before an earlier one is on chain.
    public let networkFee: String?
    public let networkFeeSymbol: String
    /// `nil` for a payment being finished: its terms were fixed when it was sent.
    public let expiresAt: Date?
    /// The provider's estimate from sending to the credit, for display; `nil` when it gives none.
    public let estimatedDurationSeconds: Int?
    /// `nil` when unknown.
    public let providerFees: PerpsDepositProviderFees?
    /// Where paying delegates the wallet's address to HermesDelegateV1 (EIP-7702), which it
    /// keeps after the deposit: Ethereum for a key registration, the source chain for a folded
    /// batch.
    public let delegatedChains: [MultichainChain]
    /// Lighter knows no account for the beneficiary: this deposit creates it. `false` also when Lighter did not answer.
    public let createsAccount: Bool

    let payment: Payment
    /// The quote whose main payload a relayed fee method is priced for; `nil` where only the chain's own coin can pay.
    var feeQuote: PerpsDepositQuote? = nil
    /// `networkFee` in the coin's smallest units.
    public internal(set) var networkFeeUnits: BigUInt? = nil
    /// What confirming signs first while the chain's own coin pays, as the checks read it: the
    /// payment, or the documents a key registration signs before its payment is quoted.
    var review: OperationReview? = nil
    public internal(set) var sentAmount: String? = nil
    public internal(set) var provider: String? = nil

    public var resumesPayment: Bool {
        if case .resuming = payment { return true }
        return false
    }

    public var accountUninitialized: Bool? {
        switch payment {
        case let .quoted(quote): quote.accountUninitialized
        case let .registering(preview): preview.accountUninitialized
        case .resuming: nil
        }
    }

    /// The chain's own coin a jetton payment carries for the jetton wallet's gas, apart from the
    /// network fee. `nil` for a coin source, whose amount is that coin, and for a payment already sent.
    public var carriedNativeAmount: String? {
        guard let quote = feeQuote, case .token = quote.sourceAsset.kind else { return nil }
        let units = quote.payloads.reduce(BigUInt(0)) { $0 + (BigUInt($1.valueUnits, radix: 10) ?? 0) }
        guard units > 0 else { return nil }
        return PerpsFundingAmount.declaredAmount(units: units, decimals: quote.sourceAsset.nativeDecimals)
    }

    /// What confirming with `relayedFee` signs first, as the checks read it: a key registration's
    /// documents whatever pays the fee, a payment only while the chain's own coin pays it. A relayed
    /// method signs the relayer's operation instead, which the final gate reads once it is prepared.
    /// `nil` when there is nothing to show.
    public func review(relayedFee: MultichainSwapFeeOption?) -> OperationReview? {
        if case .quoted = payment, relayedFee?.method.isRelayed == true { return nil }
        return review
    }
}

/// One wallet's deposit: quotes, checks the terms against its own request, sends the
/// operation in one unlock, persisting transport evidence and recording the deposit with the
/// backend before broadcast, and leaves the rest to `PerpsFundingRecovery`.
public actor PerpsDepositService {
    /// What the gateway credits, always. The quote reader refuses an output naming
    /// anything else, so the target is not the caller's to choose.
    public static let targetAsset = PerpsFundingAsset(
        assetId: PerpsFundingAssetId.usdcEthereum,
        symbol: "USDC",
        decimals: PerpsFundingAmount.usdcDecimals
    )

    /// The chain a deposit of `assetId` pays on, or `nil` when this service cannot pay from it.
    public static func fundingChain(assetId: String) -> MultichainChain? {
        PerpsFundingAssetId.parse(assetId)?.chain
    }

    /// How much less than its preview the signed key-registration quote may credit. The two are
    /// asked seconds apart, but the aggregator prices the signed calls as a new quote, so they
    /// need not agree to the unit.
    static let registrationRepriceToleranceBps: BigUInt = 100
    static let bitcoinFeeRiseToleranceBps: BigUInt = 100

    private let walletId: String
    private let walletIdentity: String
    private let environment: String
    private let journal: PerpsPendingJournal
    private let api: PerpsAPI
    private let delivery: any PerpsDepositDelivery
    private let gate: OperationGate
    private let recovery: PerpsFundingRecovery?
    private let registrar: PerpsDepositRegistrar
    /// The wallet's trading key, named on each deposit quote once derived.
    private let keyRegistration: @Sendable () async -> PerpsKeyRegistration?
    /// The contracts a deposit may delegate to or register the key with, as the backend signed
    /// them; `nil` when no signed block has verified, and then nothing naming them is signed.
    private let securityConfig: @Sendable () async -> PerpsSecurityConfig?
    private let downloadedSecurityConfig: @Sendable () async -> PerpsSecurityConfig?
    private let ensureBinding: @Sendable (String) async throws -> Void
    private let relaying: PerpsDepositRelaying?
    private let now: @Sendable () -> Date
    private let makeOperationId: @Sendable () -> String
    /// One `pay` at a time: a second tap must not send the same quote twice.
    private var isPaying = false
    /// The quote a key registration was signed for, by its preview: confirming the preview again
    /// pays that quote rather than a new one.
    private var registered: (previewId: String, quote: PerpsDepositQuote)?

    init(
        walletId: String,
        walletIdentity: String,
        environment: String,
        journal: PerpsPendingJournal,
        api: PerpsAPI,
        delivery: any PerpsDepositDelivery,
        gate: OperationGate,
        recovery: PerpsFundingRecovery? = nil,
        keyRegistration: @escaping @Sendable () async -> PerpsKeyRegistration? = { nil },
        securityConfig: @escaping @Sendable () async -> PerpsSecurityConfig? = { nil },
        downloadedSecurityConfig: @escaping @Sendable () async -> PerpsSecurityConfig? = { nil },
        ensureBinding: @escaping @Sendable (String) async throws -> Void = { _ in },
        relaying: PerpsDepositRelaying? = nil,
        now: @escaping @Sendable () -> Date = { Date() },
        makeOperationId: @escaping @Sendable () -> String = { UUID().uuidString }
    ) {
        self.walletId = walletId
        self.walletIdentity = walletIdentity
        self.environment = environment
        self.journal = journal
        self.api = api
        self.delivery = delivery
        self.gate = gate
        self.recovery = recovery
        registrar = PerpsDepositRegistrar(api: api, journal: journal)
        self.keyRegistration = keyRegistration
        self.securityConfig = securityConfig
        self.downloadedSecurityConfig = downloadedSecurityConfig
        self.ensureBinding = ensureBinding
        self.relaying = relaying
        self.now = now
        self.makeOperationId = makeOperationId
    }

    /// A payment quote without key registration, used to estimate the source fee.
    func quote(
        sourceAsset: String,
        sourceAmountUnits: String,
        senderAddress: String,
        beneficiary: String
    ) async throws -> PerpsDepositQuote {
        let request = Components.Schemas.DepositQuoteRequest(
            source_asset: sourceAsset,
            source_amount: sourceAmountUnits,
            sender_address: senderAddress,
            destination_address: beneficiary
        )
        let security = await securityConfig(forSourceAsset: sourceAsset)
        return try await read(requestQuote(request), request: request, registration: nil, security: security)
    }

    private func securityConfig(forSourceAsset sourceAsset: String) async -> PerpsSecurityConfig? {
        let security = await securityConfig()
        guard let asset = PerpsFundingAssetId.parse(sourceAsset), asset.chain.isEVM,
              asset.raw.lowercased() != PerpsFundingAssetId.usdcEthereum,
              let security, security.relayRouters[asset.chain.rawValue]?.isEmpty ?? true
        else { return security }
        return await downloadedSecurityConfig() ?? security
    }

    private func requestQuote(_ request: Components.Schemas.DepositQuoteRequest) async throws -> Components.Schemas.DepositQuote {
        return try await PerpsOperationLog.step("quote", source: "backend", fields: ["flow": "deposit", "wallet_id": walletId, "asset_id": request.source_asset, "amount_units": request.source_amount, "key_registration": String(request.change_pub_key != nil), "signed_registration": String(request.operation != nil)]) {
            let quoted: Components.Schemas.DepositQuote
            do {
                quoted = try await api.quoteDeposit(walletId: walletId, request: request)
            } catch {
                if case let .transport(underlying?) = error as? PerpsAPIError,
                   let clientError = underlying as? ClientError,
                   let body = await clientError.undecodedResponseBody()
                {
                    PerpsOperationLog.event("quote", outcome: "undecodable", source: "backend_or_client_contract", error: error, fields: ["responseBody": body])
                }
                throw error
            }
            try Task.checkCancellation()
            PerpsOperationLog.event("quote", outcome: "received", source: "backend", fields: [
                "quote_id": quoted.quote_id, "provider": quoted.provider,
                "input_units": quoted.input.amount, "output_units": quoted.output.amount,
                "minimum_output_units": quoted.output.min_amount,
                "expires_at": String(quoted.expires_at.timeIntervalSince1970),
                "execution_id": quoted.tracking?.execution_id ?? "none",
                "preview": String(quoted.preview), "payload_count": String(quoted.operation.payloads.count),
                "account_uninitialized": quoted.account_uninitialized.map { String($0) } ?? "unknown",
            ])
            return quoted
        }
    }

    private func read(
        _ quoted: Components.Schemas.DepositQuote,
        request: Components.Schemas.DepositQuoteRequest,
        registration: PerpsKeyRegistration?,
        security: PerpsSecurityConfig?
    ) async throws -> PerpsDepositQuote {
        var quote: PerpsDepositQuote
        do {
            quote = try PerpsDepositQuoteReader.read(quoted, request: request, registration: registration, security: security, now: now())
            try Self.checkTerms(of: &quote, security: security)
            if let bitcoin = quote.bitcoinPayment {
                let bytePrice = await delivery.bitcoinBytePrice(paying: bitcoin.sentUnits, from: quote.sender)
                try Task.checkCancellation()
                try PerpsBitcoinDepositReader.checkFeeRate(bitcoin, walletBytePrice: bytePrice)
            }
        } catch {
            PerpsOperationLog.event("quote_validation", outcome: "rejected", source: "backend_or_client_contract", error: error, fields: ["quote_id": quoted.quote_id])
            throw error
        }
        if quote.sourceAsset.chain == .tron {
            quote.operation = try await chargingTronNetworkFee(quote.operation, quoteId: quote.quoteId)
        }
        return quote
    }

    private func chargingTronNetworkFee(_ operation: PerpsDepositOperation, quoteId: String) async throws -> PerpsDepositOperation {
        let quoted = try operation.quotedFeeUnits(on: .tron)
        guard !quoted.isEmpty else { return operation }
        let estimated = await delivery.walletNetworkFeeUnits(of: operation, on: .tron)
        try Task.checkCancellation()
        var bandwidthUnits: BigUInt?
        var charged = [String: BigUInt]()
        for (payloadId, quotedUnits) in quoted {
            let units: BigUInt
            if let estimate = estimated[payloadId] {
                units = estimate
            } else {
                if bandwidthUnits == nil {
                    bandwidthUnits = await delivery.tronBandwidthFeeUnits()
                    try Task.checkCancellation()
                }
                guard let bandwidth = bandwidthUnits else {
                    PerpsOperationLog.event("network_fee", outcome: "unavailable", source: "chain_rpc", fields: ["quote_id": quoteId, "payload_id": payloadId, "chain": MultichainChain.tron.rawValue])
                    throw PerpsDepositServiceError.networkFeeUnavailable
                }
                units = quotedUnits + bandwidth
            }
            PerpsOperationLog.event("network_fee", outcome: units > quotedUnits ? "raised" : "quoted", source: "wallet", fields: [
                "quote_id": quoteId, "payload_id": payloadId, "chain": MultichainChain.tron.rawValue,
                "quoted_units": quotedUnits.description, "wallet_units": estimated[payloadId]?.description ?? "none",
                "bandwidth_units": bandwidthUnits?.description ?? "none",
            ])
            if units > quotedUnits { charged[payloadId] = units }
        }
        return try operation.charging(charged)
    }

    /// Signs what the preview asks for and asks again with the signatures: that answer is the
    /// quote to send, re-priced, since the aggregator's quote is bound to the signed calls.
    private func registeredQuote(
        _ preview: PerpsKeyRegistrationPreview,
        sourceAsset: PerpsFundingAsset,
        shownFeeUnits: BigUInt?,
        session: any PerpsDepositSigningSession,
        consent: OperationConsent
    ) async throws -> PerpsDepositQuote {
        return try await PerpsOperationLog.step("registration_quote", source: "wallet", fields: ["flow": "deposit", "wallet_id": walletId, "quote_id": preview.quoteId]) {
            try Task.checkCancellation()
            try await clear(.ask, consent: consent) { try [documentsSignable(preview, sourceAsset: sourceAsset)] }
            guard preview.expiresAt > now() else { throw PerpsDepositServiceError.quoteExpired(preview.quoteId) }
            let signed = try await session.signDocuments(preview.operation, owner: preview.beneficiary)
            let request = try Components.Schemas.DepositQuoteRequest(
                source_asset: preview.sourceAsset.raw,
                source_amount: preview.sourceAmountUnits,
                sender_address: preview.sender,
                destination_address: preview.beneficiary,
                change_pub_key: preview.registration.request(),
                operation: preview.signedOperation(signed)
            )
            let quote = try await read(requestQuote(request), request: request, registration: preview.registration, security: preview.security)
            let quoted = try PerpsFundingAmount.integerUnits(quote.depositAmountUnits)
            let previewed = try PerpsFundingAmount.integerUnits(preview.depositAmountUnits)
            guard quoted * 10000 >= previewed * (10000 - Self.registrationRepriceToleranceBps) else {
                throw PerpsDepositServiceError.registrationRepriced(quoted: quote.depositAmountUnits, previewed: preview.depositAmountUnits)
            }
            if let fee = quote.bitcoinPayment?.feeUnits {
                guard let shownFeeUnits, fee * 10000 <= shownFeeUnits * (10000 + Self.bitcoinFeeRiseToleranceBps) else {
                    throw PerpsDepositServiceError.bitcoinFeeRaised(quoted: fee.description, shown: shownFeeUnits?.description ?? "none")
                }
            }
            return quote
        }
    }

    /// Quotes, checks what it would sign, and prices it. No side effect: nothing is written
    /// and nothing is unlocked, so a review can be repeated.
    ///
    /// The backend decides whether the trading key needs registration. `registeringKey: false`
    /// asks only for the payment used to estimate the fee. `previewing: false` checks nothing, for
    /// a review that is only priced and never confirmed.
    public func review(
        sourceAsset: PerpsFundingAsset,
        amount: String,
        senderAddress: String,
        beneficiary: String,
        registeringKey: Bool = true,
        previewing: Bool = true
    ) async throws -> PerpsDepositReview {
        return try await PerpsOperationLog.step("prepare_quote", source: "client", fields: ["flow": "deposit", "wallet_id": walletId, "asset_id": sourceAsset.assetId, "amount": amount]) {
            // The screen hands over what the user typed; turning it into units is a money rule
            // and stays here, where the decimals of the asset it belongs to are known.
            let amountUnits = try PerpsFundingAmount.units(
                declaredAmount: amount,
                decimals: sourceAsset.decimals
            )
            let registration = registeringKey ? await keyRegistration() : nil
            guard !registeringKey || registration != nil else {
                throw PerpsDepositQuoteError.malformedKeyRegistration("trading key unavailable")
            }
            let request = Components.Schemas.DepositQuoteRequest(
                source_asset: sourceAsset.assetId,
                source_amount: amountUnits.description,
                sender_address: senderAddress,
                destination_address: beneficiary,
                change_pub_key: registration?.request()
            )
            let security = await securityConfig(forSourceAsset: sourceAsset.assetId)
            let quoted = try await requestQuote(request)
            let quote: PerpsDepositQuote
            let payment: PerpsDepositReview.Payment
            if quoted.preview {
                guard let registration else { throw PerpsDepositQuoteError.unexpectedPreview(true) }
                guard let security else {
                    throw PerpsDepositQuoteError.malformedKeyRegistration("perps_security")
                }
                payment = try .registering(PerpsDepositQuoteReader.readPreview(
                    quoted,
                    request: request,
                    registration: registration,
                    security: security,
                    now: now()
                ))
                // A preview contains signatures only; the payment quote supplies the source fee.
                quote = try await self.quote(
                    sourceAsset: sourceAsset.assetId,
                    sourceAmountUnits: amountUnits.description,
                    senderAddress: senderAddress,
                    beneficiary: beneficiary
                )
            } else {
                quote = try await read(quoted, request: request, registration: registration, security: security)
                payment = .quoted(quote)
            }
            let feeUnits: BigUInt?
            let isEthereumRegistration = if case let .registering(preview) = payment { preview.sourceAsset.chain == .eth } else { false }
            if let bitcoin = quote.bitcoinPayment {
                feeUnits = bitcoin.feeUnits
            } else if isEthereumRegistration {
                feeUnits = quote.operation.quotedNetworkFeeUnits(on: quote.sourceAsset.chain)
            } else {
                feeUnits = await delivery.networkFeeUnits(of: quote.operation, on: quote.sourceAsset.chain)
            }
            var creditedUnits = quote.depositAmountUnits
            var expiresAt = quote.expiresAt
            var estimatedDurationSeconds = quote.estimatedDurationSeconds
            var providerFees = quote.providerFees
            var delegatedChains = quote.payloads.contains { $0.delegation != nil } ? [quote.sourceAsset.chain] : []
            if case let .registering(preview) = payment {
                (creditedUnits, expiresAt) = (preview.depositAmountUnits, preview.expiresAt)
                estimatedDurationSeconds = preview.estimatedDurationSeconds
                providerFees = preview.providerFees
                delegatedChains = [.eth] + delegatedChains.filter { $0 != .eth }
            }
            // A registration's payment is quoted again once its documents are signed, so only they are known.
            let operationReview: OperationReview? = if previewing {
                await gate.preview(.ask) {
                    if case let .registering(preview) = payment {
                        return try [documentsSignable(preview, sourceAsset: sourceAsset)]
                    }
                    return try [paymentSignable(quote.operation, sourceAsset: sourceAsset, units: quote.sourceAmountUnits, sender: quote.sender)]
                }
            } else {
                nil
            }
            return try PerpsDepositReview(
                sourceAsset: sourceAsset,
                sourceChain: quote.sourceAsset.chain,
                sourceAmount: PerpsFundingAmount.declaredAmount(units: amountUnits, decimals: sourceAsset.decimals),
                creditedAmount: PerpsFundingAmount.declaredAmount(
                    units: PerpsFundingAmount.integerUnits(creditedUnits),
                    decimals: PerpsFundingAmount.usdcDecimals
                ),
                networkFee: feeUnits.map {
                    PerpsFundingAmount.declaredAmount(units: $0, decimals: quote.sourceAsset.nativeDecimals)
                },
                networkFeeSymbol: quote.sourceAsset.nativeSymbol,
                expiresAt: expiresAt,
                estimatedDurationSeconds: estimatedDurationSeconds,
                providerFees: providerFees,
                delegatedChains: delegatedChains,
                // The first answer, not a preview's plain re-quote: only a quote with change_pub_key waits for Lighter.
                createsAccount: quoted.account_uninitialized == true,
                payment: payment,
                // From Ethereum the registered payment carries a delegation, which the relayer does not.
                feeQuote: isEthereumRegistration ? nil : quote,
                networkFeeUnits: feeUnits,
                review: operationReview,
                sentAmount: quote.relayPaymentUnits.map {
                    PerpsFundingAmount.declaredAmount(units: $0, decimals: sourceAsset.decimals)
                },
                provider: quote.relayPaymentUnits == nil ? nil : PerpsDepositProvider.relayName
            )
        }
    }

    /// The relayed ways to pay the review's source fee, in the order to offer them; empty where
    /// only the chain's own coin can. `walletAsset` is the source as the wallet holds it, which a
    /// fee in that asset is weighed against next to the amount.
    public func feeOptions(of review: PerpsDepositReview, walletAsset: MultichainAsset) async -> [MultichainSwapFeeOption] {
        guard let relaying, let quote = review.feeQuote,
              let context = relaying.context(quote: quote, walletAsset: walletAsset)
        else { return [] }
        return await relaying.options(context: context)
    }

    /// The least a deposit of `sourceAsset` may be: the gateway's floor for USDC itself; for another
    /// asset the dollars the service names when it refuses half a dollar's worth, which move with the
    /// route's fees, in units at `usdPrice` rounded up. `nil` when the probe is quoted or refused otherwise;
    /// throws a refusal no amount clears: of the sender itself, or of the region.
    public func minimum(
        sourceAsset: PerpsFundingAsset,
        usdPrice: Decimal,
        senderAddress: String,
        beneficiary: String
    ) async throws -> (usd: String, units: BigUInt)? {
        if sourceAsset.assetId.lowercased() == Self.targetAsset.assetId {
            let units = PerpsFundingAmount.gatewayMinimumUsdcUnits
            return (PerpsFundingAmount.declaredAmount(units: units, decimals: PerpsFundingAmount.usdcDecimals), units)
        }
        guard usdPrice > 0 else { return nil }
        let request = Components.Schemas.DepositQuoteRequest(
            source_asset: sourceAsset.assetId,
            source_amount: max(Self.units(usd: Self.minimumProbeUsd, price: usdPrice, decimals: sourceAsset.decimals, .down), 1).description,
            sender_address: senderAddress,
            destination_address: beneficiary
        )
        let usd: String
        do {
            _ = try await requestQuote(request)
            return nil
        } catch let PerpsAPIError.badStatus(failure) where failure.reason == "amount_too_low" {
            guard let minimum = failure.minUsdAmount else { return nil }
            usd = minimum
        } catch let PerpsAPIError.badStatus(failure)
            where failure.reason == Self.blockedSenderReason || failure.code == Self.regionRestrictedCode
        {
            throw PerpsAPIError.badStatus(failure)
        } catch {
            return nil
        }
        guard let value = Decimal(string: usd, locale: Locale(identifier: "en_US_POSIX")), value > 0 else { return nil }
        return (usd, Self.units(usd: value, price: usdPrice, decimals: sourceAsset.decimals, .up))
    }

    static let minimumProbeUsd: Decimal = 0.5
    /// The deposit provider's AML check refuses the sender address.
    static let blockedSenderReason = "invalid_sender_address"
    static let regionRestrictedCode = "region_restricted"

    static func units(usd: Decimal, price: Decimal, decimals: Int, _ rounding: NSDecimalNumber.RoundingMode) -> BigUInt {
        var value = usd / price * pow(10, decimals)
        var whole = Decimal()
        NSDecimalRound(&whole, &value, 0, rounding)
        return BigUInt(NSDecimalNumber(decimal: whole).stringValue) ?? 0
    }

    /// An unfinished transport or registration belonging to this wallet.
    public func pendingReview() async throws -> PerpsDepositReview? {
        return try await PerpsOperationLog.step("journal_pending", source: "client", fields: ["flow": "deposit", "wallet_id": walletId], quiet: true) {
            guard let pending = try await ownFunding().first(where: { $0.deposit?.requiresResume == true }) else {
                return nil
            }
            var review = try Self.review(resuming: pending)
            if let deposit = pending.deposit, let units = try await self.checkedUnsignedTonPayment(of: deposit) {
                review.sentAmount = PerpsFundingAmount.declaredAmount(units: units, decimals: deposit.sourceAsset.decimals)
                review.provider = PerpsDepositProvider.relayName
            }
            return review
        }
    }

    private static func review(resuming operation: PerpsPendingFundingOperation) throws -> PerpsDepositReview {
        guard let deposit = operation.deposit, let creditedUnits = deposit.gatewayAmountUnits ?? deposit.minimumTargetAmountUnits else {
            throw PerpsDepositRegistrationError.notADeposit(operation.operationId)
        }
        guard let sourceAssetId = PerpsFundingAssetId.parse(deposit.sourceAsset.assetId) else {
            throw PerpsDepositQuoteError.unsupportedSourceAsset(deposit.sourceAsset.assetId)
        }
        return try PerpsDepositReview(
            sourceAsset: deposit.sourceAsset,
            sourceChain: sourceAssetId.chain,
            sourceAmount: PerpsFundingAmount.declaredAmount(
                units: PerpsFundingAmount.integerUnits(deposit.sourceAmountUnits),
                decimals: deposit.sourceAsset.decimals
            ),
            creditedAmount: PerpsFundingAmount.declaredAmount(
                units: PerpsFundingAmount.integerUnits(creditedUnits),
                decimals: PerpsFundingAmount.usdcDecimals
            ),
            // Already-spent source funds must not be checked against today's balance.
            networkFee: nil,
            networkFeeSymbol: sourceAssetId.nativeSymbol,
            expiresAt: deposit.relayAttempted == true ? nil : deposit.transmission.flatMap { transmission in
                let mainId = try? transmission.operation.parsed().payloads.last?.id
                return transmission.steps.contains { $0.payloadId == mainId && $0.broadcastAttempted } ? nil : transmission.expiresAt
            },
            estimatedDurationSeconds: deposit.estimatedDurationSeconds,
            providerFees: nil,
            delegatedChains: [],
            createsAccount: false,
            payment: .resuming(operationId: operation.operationId)
        )
    }

    /// Persists every signature before broadcast and keeps uncertain submissions resumable.
    /// Ethereum key registration checks its final fee after signing the preview, within the same payment.
    ///
    /// Whatever is signed is cleared by the gate first, under `consent`, before a new payment is journaled:
    /// a review it already accepted passes, a decline fails as a `CancellationError`, and what could
    /// not be reviewed fails as `OperationRefusal.unreviewable`, never as a cancellation.
    ///
    /// `relayedFee` is one of `feeOptions(of:walletAsset:)` for the same `walletAsset`: the relayer
    /// then signs and sends the payment, and the chain's own coin pays nothing.
    public func pay(
        review: PerpsDepositReview,
        passcode: String,
        consent: OperationConsent,
        relayedFee: MultichainSwapFeeOption? = nil,
        walletAsset: MultichainAsset? = nil,
        validateNetworkFee: @Sendable (String) async throws -> Void = { _ in }
    ) async throws -> PerpsDepositOutcome {
        return try await PerpsOperationLog.step("payment", fields: ["flow": "deposit", "wallet_id": walletId, "asset_id": review.sourceAsset.assetId, "amount": review.sourceAmount]) {
            guard !isPaying else { throw PerpsDepositServiceError.paymentInProgress }
            isPaying = true
            defer { isPaying = false }

            switch review.payment {
            case let .resuming(operationId):
                try await ensureBinding(passcode)
                try Task.checkCancellation()
                return try await resume(operationId, consent: consent) { try await self.delivery.openSession(passcode: passcode) }
            case let .quoted(quote):
                guard quote.expiresAt > now() else { throw PerpsDepositServiceError.quoteExpired(quote.quoteId) }
                let relay = try relayedPayment(quote, fee: relayedFee, walletAsset: walletAsset, passcode: passcode)
                try await ensureBinding(passcode)
                try Task.checkCancellation()
                let session = try await delivery.openSession(passcode: passcode)
                return try await pay(quote, sourceAsset: review.sourceAsset, estimatedDurationSeconds: review.estimatedDurationSeconds, session: session, relay: relay, consent: consent)
            case let .registering(preview):
                guard preview.expiresAt > now() else { throw PerpsDepositServiceError.quoteExpired(preview.quoteId) }
                try await ensureBinding(passcode)
                try Task.checkCancellation()
                let session = try await delivery.openSession(passcode: passcode)
                guard preview.expiresAt > now() else { throw PerpsDepositServiceError.quoteExpired(preview.quoteId) }
                let quote: PerpsDepositQuote
                if let registered, registered.previewId == preview.quoteId {
                    quote = registered.quote
                } else {
                    quote = try await registeredQuote(preview, sourceAsset: review.sourceAsset, shownFeeUnits: review.networkFeeUnits, session: session, consent: consent)
                    registered = (preview.quoteId, quote)
                }
                let relay = try relayedPayment(quote, fee: relayedFee, walletAsset: walletAsset, passcode: passcode)
                if preview.sourceAsset.chain == .eth {
                    guard let feeUnits = await delivery.networkFeeUnits(of: quote.operation, on: quote.sourceAsset.chain) else {
                        throw ChainKitOperationError.feeUnavailable(payloadId: quote.quoteId, reason: "key registration payment fee unavailable")
                    }
                    try await validateNetworkFee(PerpsFundingAmount.declaredAmount(units: feeUnits, decimals: quote.sourceAsset.nativeDecimals))
                    try Task.checkCancellation()
                }
                return try await pay(quote, sourceAsset: review.sourceAsset, estimatedDurationSeconds: review.estimatedDurationSeconds, session: session, relay: relay, consent: consent)
            }
        }
    }

    private func resume(
        _ operationId: String,
        consent: OperationConsent,
        session openSession: () async throws -> any PerpsDepositSigningSession
    ) async throws -> PerpsDepositOutcome {
        try await holdingDeposit(operationId) {
            guard let pending = try await ownFunding().first(where: { $0.operationId == operationId }) else {
                throw PerpsDepositServiceError.resumedPaymentChanged(operationId)
            }
            // The recovery pass this payment waited for may have carried it past sending.
            guard pending.deposit?.requiresResume == true else {
                switch pending.deposit?.stage {
                case .registrationPending, .registeredPending, .credited, .unconfirmed:
                    return try await register(pending)
                case .failed, .refunded:
                    throw PerpsDepositServiceError.registrationRejected(operationId)
                default:
                    throw PerpsDepositServiceError.resumedPaymentChanged(operationId)
                }
            }
            let session = try await openSession()
            if pending.deposit?.stage == .needsAuthorization {
                return try await reauthorize(pending)
            }
            if let deposit = pending.deposit, let transmission = deposit.transmission {
                _ = try await checkedUnsignedTonPayment(of: deposit)
                try await clear(.ask, consent: consent) { try unsignedSignables(of: deposit, transmission) }
                return try await send(pending, session: session)
            }
            let recovered = try await recoverLegacy(pending)
            return try await reauthorize(recovered)
        }
    }

    private func pay(
        _ quote: PerpsDepositQuote,
        sourceAsset: PerpsFundingAsset,
        estimatedDurationSeconds: Int?,
        session: any PerpsDepositSigningSession,
        relay: RelayedPayment?,
        consent: OperationConsent
    ) async throws -> PerpsDepositOutcome {
        // The unlock may have outlived the quote.
        guard quote.expiresAt > now() else { throw PerpsDepositServiceError.quoteExpired(quote.quoteId) }
        let funding = try await ownFunding()
        if let prior = funding.first(where: { $0.deposit?.quoteId == quote.quoteId }) {
            switch prior.deposit?.stage {
            case .registrationPending, .registeredPending, .credited, .unconfirmed:
                return try await holdingDeposit(prior.operationId) {
                    try await register(journal.funding(operationId: prior.operationId) ?? prior)
                }
            case .needsAuthorization:
                return .authorizationRequired(operationId: prior.operationId)
            case .failed, .refunded:
                throw PerpsDepositServiceError.registrationRejected(prior.operationId)
            // Confirmed again after a failure that kept it, such as a fee the balance did not cover.
            case _ where prior.deposit?.requiresResume == true:
                return try await resume(prior.operationId, consent: consent) { session }
            default:
                throw PerpsDepositServiceError.paymentInProgress
            }
        }
        guard !funding.contains(where: { $0.deposit?.blocksNewPayment == true }) else {
            throw PerpsDepositServiceError.paymentInProgress
        }
        // The relayer prices and builds its operation before the payment is journaled or recorded.
        let relayed: (prepared: MultichainSwapPreparedRelay, wasLive: Bool, passcode: String)?
        if let relay {
            let prepared = try await relay.engine.prepare(context: relay.context, confirmed: relay.confirmed)
            let wasLive = !prepared.isExpired(at: now())
            try await clear(relay.presentation, consent: consent) {
                try await prepared.signables(.deposit(of: sourceAsset, units: quote.sourceAmountUnits, fee: relay.tokenFee))
            }
            relayed = (prepared, wasLive, relay.passcode)
        } else {
            try await clear(.ask, consent: consent) {
                try [paymentSignable(quote.operation, sourceAsset: sourceAsset, units: quote.sourceAmountUnits, sender: quote.sender)]
            }
            relayed = nil
        }
        try checkExpiry(of: quote, prepared: relayed?.prepared, wasLive: relayed?.wasLive ?? false)
        // The relayer and the gate were awaited: a payment journaled meanwhile still comes first.
        let journaled = try await ownFunding()
        guard !journaled.contains(where: { $0.deposit?.quoteId == quote.quoteId || $0.deposit?.blocksNewPayment == true }) else {
            throw PerpsDepositServiceError.paymentInProgress
        }
        let operationId = makeOperationId()
        var deposit = PerpsPendingDeposit(
            stage: .sourcePending,
            route: quote.route,
            beneficiary: quote.beneficiary,
            sourceAsset: sourceAsset,
            sourceAmountUnits: quote.sourceAmountUnits,
            targetAsset: Self.targetAsset,
            minimumTargetAmountUnits: quote.depositAmountUnits,
            executionId: quote.executionId,
            quoteId: quote.quoteId
        )
        deposit.estimatedDurationSeconds = estimatedDurationSeconds
        deposit.transmission = PerpsDepositTransmission(operation: quote.operation, sender: quote.sender, expiresAt: quote.expiresAt, steps: [])
        let operation = PerpsPendingFundingOperation(
            operationId: operationId,
            walletId: walletId,
            walletIdentity: walletIdentity,
            environment: environment,
            createdAtMillis: Int64(now().timeIntervalSince1970 * 1000),
            details: .deposit(deposit)
        )
        return try await holdingDeposit(operationId) {
            let saved = try await journal.saveFundingIfAbsent(operation)
            guard saved.inserted else { throw PerpsDepositServiceError.paymentInProgress }
            if let relayed {
                return try await self.relay(saved.operation, quote: quote, prepared: relayed.prepared, wasLive: relayed.wasLive, passcode: relayed.passcode)
            }
            return try await send(saved.operation, session: session)
        }
    }

    private struct RelayedPayment {
        let context: MultichainSwapFeeContext
        let confirmed: MultichainSwapRelayedFee
        let tokenFee: OperationIntent.Spend?
        let engine: any MultichainSwapRelayedFeeEngine
        let passcode: String

        /// Battery charges on an EVM chain are asked about. A TON payment, and a fee in a token
        /// until the backend confirms the relayer's fee on its payload, are only logged.
        var presentation: OperationPresentation {
            if context.payload.chain.isEVM, case .batteryCharges = confirmed {
                return .ask
            }
            return .logOnly
        }
    }

    /// `nil` for the chain's own coin. The quote paid may be another than the one the method was
    /// priced for — a registration's is quoted again once signed — so it is checked against that one.
    private func relayedPayment(
        _ quote: PerpsDepositQuote,
        fee: MultichainSwapFeeOption?,
        walletAsset: MultichainAsset?,
        passcode: String
    ) throws -> RelayedPayment? {
        guard let fee, fee.method.isRelayed else { return nil }
        guard !fee.isInsufficient, let confirmed = fee.relayedFee, let walletAsset, let relaying,
              let context = relaying.context(quote: quote, walletAsset: walletAsset),
              let engine = relaying.engine(for: context)
        else {
            PerpsOperationLog.event("fee_method", outcome: "unavailable", fields: ["quote_id": quote.quoteId, "fee_method": fee.logValue])
            throw PerpsDepositServiceError.relayUnavailable
        }
        return RelayedPayment(context: context, confirmed: confirmed, tokenFee: fee.tokenFee, engine: engine, passcode: passcode)
    }

    /// Recorded by its execution before the relayer is asked, as the coin's path records it before
    /// its first broadcast; the relayer then signs and sends what was prepared and reviewed.
    private func relay(
        _ operation: PerpsPendingFundingOperation,
        quote: PerpsDepositQuote,
        prepared: MultichainSwapPreparedRelay,
        wasLive: Bool,
        passcode: String
    ) async throws -> PerpsDepositOutcome {
        return try await PerpsOperationLog.step("relay", source: "backend", fields: operation.operationLogFields) {
            guard let deposit = operation.deposit else { throw PerpsDepositServiceError.resumedPaymentChanged(operation.operationId) }
            var current: PerpsPendingFundingOperation
            do {
                let registration = try makeRegistration(operationId: operation.operationId, deposit: deposit)
                current = try await journal.updateFunding(operationId: operation.operationId, expectedRevision: operation.revision) { stored in
                    guard var deposit = stored.deposit else { return }
                    deposit.registration = registration
                    stored.details = .deposit(deposit)
                }
                current = try await registrar.recordBeforeBroadcast(operation: current)
                try checkExpiry(of: quote, prepared: prepared, wasLive: wasLive)
                // Marked before the relayer is asked: a request it leaves unanswered may still land.
                current = try await journal.updateFunding(operationId: current.operationId, expectedRevision: current.revision) { stored in
                    guard var deposit = stored.deposit else { return }
                    deposit.relayAttempted = true
                    stored.details = .deposit(deposit)
                }
            } catch {
                // Nothing is out before the relayer is asked, and a payment kept from then would be
                // resumed with the chain's own coin: it is dropped, as a send with no step is.
                guard let stored = try await journal.funding(operationId: operation.operationId),
                      stored.deposit?.relayAttempted != true
                else { throw error }
                try await journal.removeFunding(operationId: stored.operationId, expectedRevision: stored.revision)
                throw error
            }
            PerpsOperationLog.event("relay", outcome: "sending", source: "backend", fields: current.operationLogFields)
            let hash: String?
            do throws(MultichainSwapExecutionFailure) {
                hash = try await prepared.send(.mnemonic { passcode })
            } catch {
                PerpsOperationLog.event("relay", outcome: "unknown", source: "backend", error: error, fields: current.operationLogFields)
                guard error.mayHaveRelayed else {
                    try await journal.removeFunding(operationId: current.operationId, expectedRevision: current.revision)
                    throw error
                }
                hash = nil
            }
            if let hash {
                current = try await journal.updateFunding(operationId: current.operationId, expectedRevision: current.revision) { stored in
                    guard var deposit = stored.deposit else { return }
                    deposit.sourceTxHash = hash
                    stored.details = .deposit(deposit)
                }
            }
            do {
                return try await finishRegistration(current)
            } catch {
                if case PerpsDepositServiceError.registrationRejected = error { throw error }
                PerpsOperationLog.event("register", outcome: "deferred", source: "backend", error: error, fields: current.operationLogFields)
                return .authorizationRequired(operationId: current.operationId)
            }
        }
    }

    /// Keeps recovery off the operation while this payment drives it; `body` reads the
    /// operation only once the hold is taken, after any pass already driving it. The release
    /// is awaited, so it lands before `pay` returns and cannot undo the hold of a retry that follows.
    private func holdingDeposit(
        _ operationId: String,
        _ body: () async throws -> PerpsDepositOutcome
    ) async throws -> PerpsDepositOutcome {
        await recovery?.holdDeposit(operationId)
        do {
            let outcome = try await body()
            await recovery?.releaseDeposit(operationId)
            return outcome
        } catch {
            await recovery?.releaseDeposit(operationId)
            throw error
        }
    }

    private func recoverLegacy(_ operation: PerpsPendingFundingOperation) async throws -> PerpsPendingFundingOperation {
        guard let deposit = operation.deposit else { return operation }
        guard let step = deposit.route == .crosschainSwap ? deposit.sourceStep : deposit.gatewayStep else {
            return operation
        }
        guard let chain = Self.fundingChain(assetId: deposit.sourceAsset.assetId) else {
            throw PerpsDepositServiceError.resumedPaymentChanged(operation.operationId)
        }
        let expiresAt = deposit.route == .crosschainSwap ? deposit.quoteExpiresAtMillis.map { Date(timeIntervalSince1970: Double($0) / 1000) } : nil
        do {
            try await delivery.broadcastLegacy(step, on: chain, expiresAt: expiresAt)
        } catch ChainKitOperationError.quoteExpired {
            // The recorded hash/execution can still be reconciled, but stale relay terms cannot be paid.
            return operation
        }
        return try await journal.updateFunding(operationId: operation.operationId, expectedRevision: operation.revision) { stored in
            guard var deposit = stored.deposit else { return }
            deposit.sourceStep?.state = .accepted
            deposit.gatewayStep?.state = .accepted
            deposit.sourceTxHash = step.txHash
            deposit.stage = .needsAuthorization
            stored.details = .deposit(deposit)
        }
    }

    private func send(_ operation: PerpsPendingFundingOperation, session: any PerpsDepositSigningSession) async throws -> PerpsDepositOutcome {
        return try await PerpsOperationLog.step("broadcast", source: "chain_rpc", fields: operation.operationLogFields) {
            guard let deposit = operation.deposit, let transmission = deposit.transmission,
                  let chain = Self.fundingChain(assetId: deposit.sourceAsset.assetId)
            else { throw PerpsDepositServiceError.resumedPaymentChanged(operation.operationId) }
            // Already with the relayer: sending it again could pay twice.
            if deposit.relayAttempted == true {
                return try await finishRegistration(operation)
            }
            PerpsOperationLog.event("broadcast", outcome: "sending", source: "chain_rpc", fields: operation.operationLogFields)

            // A resumed payment whose registration was built but never posted.
            try await registrar.recordBeforeBroadcast(operation: operation)
            do {
                _ = try await session.send(
                    transmission.operation,
                    on: chain,
                    sender: transmission.sender,
                    expiresAt: transmission.expiresAt,
                    saved: transmission.steps
                ) { step in
                    try await self.persist(step, operationId: operation.operationId)
                }
            } catch {
                let current = try await journal.funding(operationId: operation.operationId)
                guard let current else { throw error }
                let steps = current.deposit?.transmission?.steps ?? []
                PerpsOperationLog.event("broadcast", outcome: "unknown", source: "chain_rpc", error: error, fields: ["operation_id": operation.operationId, "chain": chain.rawValue, "tx_hashes": steps.compactMap(\.hash).joined(separator: ",")])
                if steps.isEmpty {
                    try await journal.removeFunding(operationId: operation.operationId, expectedRevision: current.revision)
                } else {
                    let mainId = try transmission.operation.parsed().payloads.last?.id
                    let main = steps.last { $0.payloadId == mainId }
                    if main?.broadcastAttempted == true,
                       deposit.route == .crosschainSwap || main?.hash != nil
                    {
                        do { return try await finishRegistration(current) } catch {
                            return .authorizationRequired(operationId: operation.operationId)
                        }
                    }
                    if (error as? ChainKitOperationError) == .quoteExpired {
                        _ = try await journal.updateFunding(operationId: operation.operationId, expectedRevision: current.revision) { stored in
                            guard var deposit = stored.deposit else { return }
                            deposit.stage = .failed
                            stored.details = .deposit(deposit)
                        }
                    }
                }
                if case ChainKitOperationError.insufficientFunds = error, let source = PerpsFundingAssetId.parse(deposit.sourceAsset.assetId) {
                    throw PerpsDepositServiceError.insufficientNetworkFee(symbol: source.nativeSymbol)
                }
                throw error
            }
            let current = try await journal.funding(operationId: operation.operationId)
            guard let current else { throw PerpsDepositServiceError.resumedPaymentChanged(operation.operationId) }
            do {
                return try await finishRegistration(current)
            } catch {
                if case PerpsDepositServiceError.registrationRejected = error { throw error }
                PerpsOperationLog.event("register", outcome: "deferred", source: "backend", error: error, fields: operation.operationLogFields)
                return .authorizationRequired(operationId: operation.operationId)
            }
        }
    }

    private func persist(_ step: ChainKitSignedTransaction, operationId: String) async throws {
        let current = try await journal.persistDepositStep(step, operationId: operationId)
        guard let deposit = current.deposit, deposit.registration == nil,
              !step.broadcastAttempted, !step.acknowledged,
              try step.payloadId == Self.recordedBeforePayloadId(of: deposit)
        else { return }
        let registration: PerpsDepositRegistration
        do {
            registration = try makeRegistration(operationId: operationId, deposit: deposit)
        } catch {
            PerpsOperationLog.event("register", outcome: "deferred", source: "backend", error: error, fields: ["operation_id": operationId])
            return
        }
        let proved = try await journal.updateFunding(operationId: operationId, expectedRevision: current.revision) { stored in
            guard var deposit = stored.deposit else { return }
            deposit.registration = registration
            stored.details = .deposit(deposit)
        }
        try await registrar.recordBeforeBroadcast(operation: proved)
    }

    /// The payload the deposit is recorded ahead of. One paid from another chain is named by
    /// its execution, so it is recorded before anything goes out; a direct one by the hash of
    /// its gateway call, so before that call.
    private static func recordedBeforePayloadId(of deposit: PerpsPendingDeposit) throws -> String? {
        let payloads = try deposit.transmission?.operation.parsed().payloads
        return deposit.route == .crosschainSwap ? payloads?.first?.id : payloads?.last?.id
    }

    private func finishRegistration(_ operation: PerpsPendingFundingOperation) async throws -> PerpsDepositOutcome {
        if operation.deposit?.registration != nil {
            let current = try await journal.updateFunding(operationId: operation.operationId, expectedRevision: operation.revision) { stored in
                guard var deposit = stored.deposit else { return }
                deposit.stage = deposit.depositId == nil ? .registrationPending : .registeredPending
                stored.details = .deposit(deposit)
            }
            return try await register(current)
        }
        return try await reauthorize(operation)
    }

    private func reauthorize(_ operation: PerpsPendingFundingOperation) async throws -> PerpsDepositOutcome {
        guard let deposit = operation.deposit else {
            throw PerpsDepositRegistrationError.notADeposit(operation.operationId)
        }
        let registration = try makeRegistration(operationId: operation.operationId, deposit: deposit)
        let updated = try await journal.updateFunding(
            operationId: operation.operationId,
            expectedRevision: operation.revision
        ) { stored in
            guard var deposit = stored.deposit else {
                throw PerpsDepositRegistrationError.notADeposit(stored.operationId)
            }
            deposit.registration = registration
            deposit.stage = .registrationPending
            stored.details = .deposit(deposit)
        }
        return try await register(updated)
    }

    /// Posted right away; `PerpsFundingRecovery` retries it.
    private func register(_ operation: PerpsPendingFundingOperation) async throws -> PerpsDepositOutcome {
        let current: PerpsPendingFundingOperation
        if operation.deposit?.stage == .registrationPending {
            do {
                current = try await registrar.register(operation: operation)
            } catch {
                PerpsOperationLog.event("register", outcome: "deferred", source: "backend", error: error, fields: operation.operationLogFields)
                return .registered(operationId: operation.operationId)
            }
        } else {
            current = operation
        }
        switch current.deposit?.stage {
        case .needsAuthorization:
            return .authorizationRequired(operationId: current.operationId)
        case .failed, .refunded:
            throw PerpsDepositServiceError.registrationRejected(current.operationId)
        default:
            return .registered(operationId: current.operationId)
        }
    }

    private func makeRegistration(
        operationId: String,
        deposit: PerpsPendingDeposit
    ) throws -> PerpsDepositRegistration {
        let units = try PerpsFundingAmount.integerUnits(deposit.gatewayAmountUnits ?? deposit.minimumTargetAmountUnits ?? "")
        return PerpsDepositRegistration(
            operationId: operationId,
            assetId: deposit.sourceAsset.assetId,
            // Declared in USDC, as the backend records it: Lighter keeps only what
            // arrives, so this stays the only copy of what was meant.
            amount: PerpsFundingAmount.declaredAmount(units: units, decimals: PerpsFundingAmount.usdcDecimals),
            // A direct deposit is named by its gateway call, one from another chain by
            // the execution the aggregator delivers.
            l1TxHash: deposit.route == .directGateway ? (deposit.gatewayStep?.txHash ?? deposit.sourceTxHash ?? deposit.sourceStep?.txHash)?.lowercased() : nil,
            executionId: deposit.executionId
        )
    }

    private static func checkTerms(of quote: inout PerpsDepositQuote, security: PerpsSecurityConfig?) throws {
        let amountUnits = try PerpsFundingAmount.integerUnits(quote.sourceAmountUnits)
        switch quote.sourceAsset.chain {
        case .ton:
            switch (quote.provider, quote.sourceAsset.kind) {
            case (.relay, .coin):
                quote.relayPaymentUnits = try PerpsTonDepositReader.read(quote.payloads, budget: amountUnits, security: security)
            // Omniston's escrow is pinned by the backend, which also names the wallet's jetton wallet.
            case (.omniston, .token):
                guard quote.payloads.map(\.kind) == [.main] else {
                    throw PerpsDepositQuoteError.unexpectedPayloads(quote.payloads.map(\.payloadId))
                }
            default:
                throw PerpsDepositQuoteError.unexpectedTonPayment("provider")
            }
        case .tron:
            quote.relayPaymentUnits = try PerpsChainDepositReader.readTron(quote, budget: amountUnits, security: security)
        case .btc:
            let bitcoin = try PerpsBitcoinDepositReader.read(quote, budget: amountUnits, security: security)
            quote.relayPaymentUnits = bitcoin.sentUnits
            quote.bitcoinPayment = bitcoin
        case .sol:
            throw PerpsDepositQuoteError.unsupportedSourceAsset(quote.sourceAsset.raw)
        case .eth, .base, .arb, .bsc, .polygon, .avax, .robinhood:
            switch quote.provider {
            case .relay:
                quote.relayPaymentUnits = try PerpsChainDepositReader.readRelay(quote, budget: amountUnits, security: security)
            case .funxyz:
                guard PerpsDepositProvider.bridgeSources.contains(quote.sourceAsset.raw.lowercased()) else {
                    throw PerpsDepositQuoteError.unexpectedChainPayment("bridge source")
                }
                guard quote.payloads.map(\.kind) == [.main], case let .token(token) = quote.sourceAsset.kind else {
                    throw PerpsDepositQuoteError.unexpectedPayloads(quote.payloads.map(\.payloadId))
                }
                try PerpsDepositCalldata.checkBridgeTransfer(quote.payloads[0], token: token, sender: quote.sender, amountUnits: amountUnits)
            case .direct:
                try checkDirect(&quote, amountUnits: amountUnits, security: security)
            case .omniston:
                throw PerpsDepositQuoteError.unexpectedProvider(quote.provider.rawValue)
            }
        }
    }

    /// The calls a direct deposit makes, checked against its own terms: the gateway call
    /// alone, behind one approval, or both folded into one self-call — which registers the
    /// key as its third call when the deposit does. An aggregator's fill registers it on
    /// Ethereum instead, under the signatures its preview was read for.
    private static func checkDirect(_ quote: inout PerpsDepositQuote, amountUnits: BigUInt, security: PerpsSecurityConfig?) throws {
        guard let gateway = security?.lighterGateway else {
            throw PerpsDepositQuoteError.unexpectedChainPayment("lighter gateway")
        }
        let (approval, main): (PerpsDepositQuotePayload?, PerpsDepositQuotePayload)
        switch quote.payloads.map(\.kind) {
        case [.main]:
            quote.registration = nil
            (approval, main) = (nil, quote.payloads[0])
        case [.approval, .main]:
            quote.registration = nil
            (approval, main) = (quote.payloads[0], quote.payloads[1])
        case [.batch]:
            let calls = try PerpsDepositCalldata.readBatch(quote.payloads[0])
            if calls.count == 3, let registration = quote.registration, let security {
                try PerpsDepositCalldata.checkKeyRegistrationCall(calls[2], registration: registration, contract: security.changePubKeyContract)
            } else {
                guard calls.count == 2 else {
                    throw PerpsDepositQuoteError.unexpectedPayloads(quote.payloads.map(\.payloadId))
                }
                quote.registration = nil
            }
            (approval, main) = (calls[0], calls[1])
        default:
            throw PerpsDepositQuoteError.unexpectedPayloads(quote.payloads.map(\.payloadId))
        }
        try PerpsDepositCalldata.checkGatewayCall(main, gateway: gateway, beneficiary: quote.beneficiary, amountUnits: amountUnits)
        guard let approval else { return }
        guard case let .token(token) = quote.sourceAsset.kind else {
            throw PerpsDepositServiceError.approvalWithoutToken(approval.payloadId)
        }
        _ = try PerpsDepositCalldata.readApproval(approval, token: token, spender: gateway, amountUnits: amountUnits)
    }

    private func ownFunding() async throws -> [PerpsPendingFundingOperation] {
        try await journal.allFunding().filter {
            $0.belongs(walletId: walletId, walletIdentity: walletIdentity, environment: environment)
        }
    }

    /// The gate, refusing as this flow fails: a decline is the user's cancellation, and what could
    /// not be reviewed fails as any payment does, never as one the user cancelled.
    private func clear(
        _ presentation: OperationPresentation,
        consent: OperationConsent,
        file: StaticString = #fileID,
        function: StaticString = #function,
        line: UInt = #line,
        _ build: () async throws -> [SignableOperation]
    ) async throws {
        do throws(OperationRefusal) {
            try await gate.clear(presentation, consent: consent, file: file, function: function, line: line, build)
        } catch .declined {
            throw CancellationError()
        }
    }

    /// Consent takes as long as the user reads. The relayer holds what it prepared to a deadline of
    /// its own, which signing must beat by a moment. A device clock already ahead of that deadline
    /// leaves it to the relayer; only a deadline live at preparation can lapse locally.
    private func checkExpiry(of quote: PerpsDepositQuote, prepared: MultichainSwapPreparedRelay?, wasLive: Bool) throws {
        guard quote.expiresAt > now(), !wasLive || prepared?.isExpired(at: now()) != true else {
            throw PerpsDepositServiceError.quoteExpired(quote.quoteId)
        }
    }

    /// What a payment signs, from the account of the asset it spends at the address it was quoted for.
    private func paymentSignable(
        _ operation: PerpsDepositOperation,
        sourceAsset: PerpsFundingAsset,
        units: String,
        sender: String
    ) throws -> SignableOperation {
        guard let chain = Self.fundingChain(assetId: sourceAsset.assetId) else {
            throw PerpsDepositQuoteError.unsupportedSourceAsset(sourceAsset.assetId)
        }
        return try SignableOperation(
            operation: operation.parsed(),
            account: delivery.account(of: sourceAsset, on: chain, sender: sender),
            intent: .deposit(of: sourceAsset, units: units),
            fidelity: .exact
        )
    }

    /// The documents a key registration signs, from the Ethereum account they are for.
    private func documentsSignable(_ preview: PerpsKeyRegistrationPreview, sourceAsset: PerpsFundingAsset) throws -> SignableOperation {
        try SignableOperation(
            operation: preview.operation.parsed(),
            account: delivery.account(of: nil, on: .eth, sender: preview.beneficiary),
            intent: .deposit(of: sourceAsset, units: preview.sourceAmountUnits),
            fidelity: .exact
        )
    }

    private func checkedUnsignedTonPayment(of deposit: PerpsPendingDeposit) async throws -> BigUInt? {
        guard let transmission = deposit.transmission,
              let sourceAsset = PerpsFundingAssetId.parse(deposit.sourceAsset.assetId), sourceAsset.chain == .ton,
              sourceAsset.kind == .coin,
              try Self.unsignedPayloadsRemain(deposit, transmission)
        else { return nil }
        let payloads = try PerpsDepositQuoteReader.payloads(
            of: transmission.operation,
            sourceAsset: sourceAsset,
            sender: transmission.sender,
            security: nil
        ).payloads
        return try await PerpsTonDepositReader.read(
            payloads,
            budget: PerpsFundingAmount.integerUnits(deposit.sourceAmountUnits),
            security: securityConfig()
        )
    }

    private static func unsignedPayloadsRemain(_ deposit: PerpsPendingDeposit, _ transmission: PerpsDepositTransmission) throws -> Bool {
        let signed = Set(transmission.steps.map(\.payloadId))
        return try deposit.relayAttempted != true
            && transmission.operation.parsed().payloads.contains(where: { !signed.contains($0.id) })
    }

    /// What resuming a payment signs: nothing once the relayer has it or every payload is signed.
    private func unsignedSignables(of deposit: PerpsPendingDeposit, _ transmission: PerpsDepositTransmission) throws -> [SignableOperation] {
        guard try Self.unsignedPayloadsRemain(deposit, transmission) else { return [] }
        return try [paymentSignable(transmission.operation, sourceAsset: deposit.sourceAsset, units: deposit.sourceAmountUnits, sender: transmission.sender)]
    }
}

private extension OperationIntent {
    /// What the user asked to deposit, which every quote of the deposit is held to: the source
    /// asset and the amount typed, and the fee a relayer takes in a token besides it.
    static func deposit(of asset: PerpsFundingAsset, units: String, fee: Spend? = nil) throws -> OperationIntent {
        let deposit = try Spend(assetId: asset.assetId, symbol: asset.symbol, decimals: asset.decimals, amount: PerpsFundingAmount.integerUnits(units))
        return .wallet(spending: [deposit], relayerFee: fee, to: nil)
    }
}

public extension PerpsDepositService {
    static func message(for error: Error) -> PerpsDepositMessage {
        switch error {
        case PerpsDepositQuoteError.belowGatewayMinimum:
            belowGatewayMinimum
        case let PerpsAPIError.badStatus(failure) where failure.code == regionRestrictedCode:
            .regionRestricted
        // The floor moves with the route's fees, so only the service knows it; absent when it could not price it.
        case let PerpsAPIError.badStatus(failure) where failure.reason == "amount_too_low":
            failure.minUsdAmount.map { .belowMinimum(usd: $0) } ?? belowGatewayMinimum
        // A Bitcoin source is quoted from the sender's own outputs, so the quote reads its balance.
        case let PerpsAPIError.badStatus(failure) where failure.reason == "insufficient_balance":
            .insufficientBalance
        case let PerpsAPIError.badStatus(failure) where failure.reason == blockedSenderReason:
            .addressBlocked
        case PerpsDepositServiceError.accountCreationPending:
            .accountCreationPending
        case let PerpsDepositServiceError.insufficientNetworkFee(symbol):
            .insufficientNetworkFee(symbol: symbol)
        case let error as PerpsAPIError where error.isAccountCreationPending:
            .accountCreationPending
        case PerpsDepositQuoteError.expired, PerpsDepositServiceError.quoteExpired,
             PerpsDepositServiceError.resumedPaymentChanged, ChainKitOperationError.quoteExpired, ChainKitOperationError.staleAuthorization,
             MultichainSwapExecutionFailure.payloadExpired:
            .quoteExpired
        case PerpsDepositServiceError.registrationRepriced, PerpsDepositServiceError.bitcoinFeeRaised:
            .quoteChanged
        // The relayer prices again before it signs: a fee that moved, or one the wallet no longer
        // covers, is quoted and priced afresh, also when the relayer refused to send for lack of funds.
        case PerpsDepositServiceError.relayUnavailable, MultichainSwapExecutionFailure.preparationFailed,
             MultichainSwapExecutionFailure.emulationFailed, MultichainSwapExecutionFailure.broadcastRefused:
            .quoteExpired
        case is CancellationError, MultichainSwapExecutionFailure.canceled:
            .canceled
        default:
            .failed
        }
    }

    private static var belowGatewayMinimum: PerpsDepositMessage {
        .belowMinimum(
            usd: PerpsFundingAmount.declaredAmount(
                units: PerpsFundingAmount.gatewayMinimumUsdcUnits,
                decimals: PerpsFundingAmount.usdcDecimals
            )
        )
    }
}
