import BigInt
import Foundation
import OpenAPIRuntime
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
    /// Where paying delegates the wallet's address to HermesDelegateV1 (EIP-7702), which it
    /// keeps after the deposit: Ethereum for a key registration, the source chain for a folded
    /// batch.
    public let delegatedChains: [MultichainChain]

    let payment: Payment

    public var resumesPayment: Bool {
        if case .resuming = payment { return true }
        return false
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

    private let walletId: String
    private let walletIdentity: String
    private let environment: String
    private let journal: PerpsPendingJournal
    private let api: PerpsAPI
    private let delivery: any PerpsDepositDelivery
    private let recovery: PerpsFundingRecovery?
    private let registrar: PerpsDepositRegistrar
    /// The wallet's trading key, named on each deposit quote once derived.
    private let keyRegistration: @Sendable () async -> PerpsKeyRegistration?
    private let ensureBinding: @Sendable (String) async throws -> Void
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
        recovery: PerpsFundingRecovery? = nil,
        keyRegistration: @escaping @Sendable () async -> PerpsKeyRegistration? = { nil },
        ensureBinding: @escaping @Sendable (String) async throws -> Void = { _ in },
        now: @escaping @Sendable () -> Date = { Date() },
        makeOperationId: @escaping @Sendable () -> String = { UUID().uuidString }
    ) {
        self.walletId = walletId
        self.walletIdentity = walletIdentity
        self.environment = environment
        self.journal = journal
        self.api = api
        self.delivery = delivery
        self.recovery = recovery
        registrar = PerpsDepositRegistrar(api: api, journal: journal)
        self.keyRegistration = keyRegistration
        self.ensureBinding = ensureBinding
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
        return try await read(requestQuote(request), request: request, registration: nil)
    }

    private func requestQuote(_ request: Components.Schemas.DepositQuoteRequest) async throws -> Components.Schemas.DepositQuote {
        let key = request.change_pub_key == nil ? "" : request.operation == nil ? " key=preview" : " key=signed"
        let requestText = "asset=\(request.source_asset) amount=\(request.source_amount)\(key)"
        Log.i("🪵 Perps deposit: quote requested \(requestText)")
        let quoted: Components.Schemas.DepositQuote
        do {
            quoted = try await api.quoteDeposit(walletId: walletId, request: request)
        } catch {
            var extraInfo = [String: String]()
            if case let .transport(underlying?) = error as? PerpsAPIError,
               let clientError = underlying as? ClientError,
               let body = await clientError.undecodedResponseBody()
            {
                extraInfo["responseBody"] = body
            }
            Log.w("🪵 Perps deposit: quote refused \(requestText)", error: error, extraInfo: extraInfo)
            throw error
        }
        try Task.checkCancellation()
        Log.i(
            "🪵 Perps deposit: quoted \(requestText) id=\(quoted.quote_id) provider=\(quoted.provider)"
                + " in=\(quoted.input.amount) out=\(quoted.output.amount) min=\(quoted.output.min_amount)"
                + " expires=\(quoted.expires_at) tracking=\(quoted.tracking?.execution_id ?? "nil")"
                + " preview=\(quoted.preview) payloads=\(quoted.operation.payloads.count)"
                + " uninitialized=\(quoted.account_uninitialized.map { "\($0)" } ?? "nil")"
        )
        return quoted
    }

    private func read(
        _ quoted: Components.Schemas.DepositQuote,
        request: Components.Schemas.DepositQuoteRequest,
        registration: PerpsKeyRegistration?
    ) throws -> PerpsDepositQuote {
        do {
            var quote = try PerpsDepositQuoteReader.read(quoted, request: request, registration: registration, now: now())
            try Self.checkTerms(of: &quote)
            return quote
        } catch {
            Log.w("🪵 Perps deposit: quote rejected id=\(quoted.quote_id) \(String(describing: error))")
            throw error
        }
    }

    /// Signs what the preview asks for and asks again with the signatures: that answer is the
    /// quote to send, re-priced, since the aggregator's quote is bound to the signed calls.
    private func registeredQuote(
        _ preview: PerpsKeyRegistrationPreview,
        session: any PerpsDepositSigningSession
    ) async throws -> PerpsDepositQuote {
        try Task.checkCancellation()
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
        let quote = try await read(requestQuote(request), request: request, registration: preview.registration)
        let quoted = try PerpsFundingAmount.integerUnits(quote.depositAmountUnits)
        let previewed = try PerpsFundingAmount.integerUnits(preview.depositAmountUnits)
        guard quoted * 10000 >= previewed * (10000 - Self.registrationRepriceToleranceBps) else {
            throw PerpsDepositServiceError.registrationRepriced(quoted: quote.depositAmountUnits, previewed: preview.depositAmountUnits)
        }
        return quote
    }

    /// Quotes, checks what it would sign, and prices it. No side effect: nothing is written
    /// and nothing is unlocked, so a review can be repeated.
    ///
    /// The backend decides whether the trading key needs registration. `registeringKey: false`
    /// asks only for the payment used to estimate the fee.
    public func review(
        sourceAsset: PerpsFundingAsset,
        amount: String,
        senderAddress: String,
        beneficiary: String,
        registeringKey: Bool = true
    ) async throws -> PerpsDepositReview {
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
        let quoted = try await requestQuote(request)
        let quote: PerpsDepositQuote
        let payment: PerpsDepositReview.Payment
        if quoted.preview {
            guard let registration else { throw PerpsDepositQuoteError.unexpectedPreview(true) }
            payment = try .registering(PerpsDepositQuoteReader.readPreview(quoted, request: request, registration: registration, now: now()))
            // A preview contains signatures only; the payment quote supplies the source fee.
            quote = try await self.quote(
                sourceAsset: sourceAsset.assetId,
                sourceAmountUnits: amountUnits.description,
                senderAddress: senderAddress,
                beneficiary: beneficiary
            )
        } else {
            quote = try read(quoted, request: request, registration: registration)
            payment = .quoted(quote)
        }
        let feeUnits: BigUInt?
        if case let .registering(preview) = payment, preview.sourceAsset.chain == .eth {
            feeUnits = quote.operation.quotedNetworkFeeUnits(on: quote.sourceAsset.chain)
        } else {
            feeUnits = await delivery.networkFeeUnits(of: quote.operation, on: quote.sourceAsset.chain)
        }
        var creditedUnits = quote.depositAmountUnits
        var expiresAt = quote.expiresAt
        var delegatedChains = quote.payloads.contains { $0.delegation != nil } ? [quote.sourceAsset.chain] : []
        if case let .registering(preview) = payment {
            (creditedUnits, expiresAt) = (preview.depositAmountUnits, preview.expiresAt)
            delegatedChains = [.eth] + delegatedChains.filter { $0 != .eth }
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
            estimatedDurationSeconds: nil,
            delegatedChains: delegatedChains,
            payment: payment
        )
    }

    /// The least a deposit of `sourceAsset` may be: the gateway's floor for USDC itself; for another
    /// asset the dollars the service names when it refuses half a dollar's worth, which move with the
    /// route's fees, in units at `usdPrice` rounded up. `nil` when the probe is quoted or refused otherwise.
    public func minimum(
        sourceAsset: PerpsFundingAsset,
        usdPrice: Decimal,
        senderAddress: String,
        beneficiary: String
    ) async -> (usd: String, units: BigUInt)? {
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
        } catch {
            return nil
        }
        guard let value = Decimal(string: usd, locale: Locale(identifier: "en_US_POSIX")), value > 0 else { return nil }
        return (usd, Self.units(usd: value, price: usdPrice, decimals: sourceAsset.decimals, .up))
    }

    static let minimumProbeUsd: Decimal = 0.5

    static func units(usd: Decimal, price: Decimal, decimals: Int, _ rounding: NSDecimalNumber.RoundingMode) -> BigUInt {
        var value = usd / price * pow(10, decimals)
        var whole = Decimal()
        NSDecimalRound(&whole, &value, 0, rounding)
        return BigUInt(NSDecimalNumber(decimal: whole).stringValue) ?? 0
    }

    /// An unfinished transport or registration belonging to this wallet.
    public func pendingReview() async throws -> PerpsDepositReview? {
        guard let pending = try await ownFunding().first(where: { $0.deposit?.requiresResume == true }) else {
            return nil
        }
        return try Self.review(resuming: pending)
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
            expiresAt: deposit.transmission.flatMap { transmission in
                let mainId = try? transmission.operation.parsed().payloads.last?.id
                return transmission.steps.contains { $0.payloadId == mainId && $0.broadcastAttempted } ? nil : transmission.expiresAt
            },
            estimatedDurationSeconds: nil,
            delegatedChains: [],
            payment: .resuming(operationId: operation.operationId)
        )
    }

    /// Persists every signature before broadcast and keeps uncertain submissions resumable.
    /// Ethereum key registration checks its final fee after signing the preview, within the same payment.
    public func pay(
        review: PerpsDepositReview,
        passcode: String,
        validateNetworkFee: @Sendable (String) async throws -> Void = { _ in }
    ) async throws -> PerpsDepositOutcome {
        guard !isPaying else { throw PerpsDepositServiceError.paymentInProgress }
        isPaying = true
        defer { isPaying = false }

        switch review.payment {
        case let .resuming(operationId):
            try await ensureBinding(passcode)
            try Task.checkCancellation()
            return try await resume(operationId) { try await self.delivery.openSession(passcode: passcode) }
        case let .quoted(quote):
            guard quote.expiresAt > now() else { throw PerpsDepositServiceError.quoteExpired(quote.quoteId) }
            try await ensureBinding(passcode)
            try Task.checkCancellation()
            let session = try await delivery.openSession(passcode: passcode)
            return try await pay(quote, sourceAsset: review.sourceAsset, session: session)
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
                quote = try await registeredQuote(preview, session: session)
                registered = (preview.quoteId, quote)
            }
            if preview.sourceAsset.chain == .eth {
                guard let feeUnits = await delivery.networkFeeUnits(of: quote.operation, on: quote.sourceAsset.chain) else {
                    throw ChainKitOperationError.feeUnavailable(payloadId: quote.quoteId, reason: "key registration payment fee unavailable")
                }
                try await validateNetworkFee(PerpsFundingAmount.declaredAmount(units: feeUnits, decimals: quote.sourceAsset.nativeDecimals))
                try Task.checkCancellation()
            }
            return try await pay(quote, sourceAsset: review.sourceAsset, session: session)
        }
    }

    private func resume(
        _ operationId: String,
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
            if pending.deposit?.transmission != nil {
                return try await send(pending, session: session)
            }
            let recovered = try await recoverLegacy(pending)
            return try await reauthorize(recovered)
        }
    }

    private func pay(
        _ quote: PerpsDepositQuote,
        sourceAsset: PerpsFundingAsset,
        session: any PerpsDepositSigningSession
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
                return try await resume(prior.operationId) { session }
            default:
                throw PerpsDepositServiceError.paymentInProgress
            }
        }
        guard !funding.contains(where: { $0.deposit?.blocksNewPayment == true }) else {
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
            return try await send(saved.operation, session: session)
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
        guard let deposit = operation.deposit, let transmission = deposit.transmission,
              let chain = Self.fundingChain(assetId: deposit.sourceAsset.assetId)
        else { throw PerpsDepositServiceError.resumedPaymentChanged(operation.operationId) }
        Log.perps.i("Deposit payment start op=\(operation.operationId) quote=\(deposit.quoteId ?? "unknown") execution=\(deposit.executionId ?? "none") chain=\(chain.rawValue)", extraInfo: ["payloads": (try? transmission.operation.parsed())?.payloads.map(\.id).joined(separator: ",") ?? "unavailable", "expires_at_ms": String(Int64(transmission.expiresAt.timeIntervalSince1970 * 1000))])
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
            Log.perps.w("Deposit submission failed op=\(operation.operationId) chain=\(chain.rawValue) hashes=\(steps.compactMap(\.hash).joined(separator: ","))", error: error)
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
            Log.w("🪵 Perps deposit: registration not recorded op=\(operation.operationId)", error: error)
            return .authorizationRequired(operationId: operation.operationId)
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
            Log.w("🪵 Perps deposit: registration deferred op=\(operationId)", error: error)
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
                Log.w("🪵 Perps deposit: registration deferred op=\(operation.operationId)", error: error)
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

    /// The calls a direct deposit makes, checked against its own terms: the gateway call
    /// alone, behind one approval, or both folded into one self-call — which registers the
    /// key as its third call when the deposit does. An aggregator's fill registers it on
    /// Ethereum instead, under the signatures its preview was read for.
    private static func checkTerms(of quote: inout PerpsDepositQuote) throws {
        let amountUnits = try PerpsFundingAmount.integerUnits(quote.sourceAmountUnits)
        let (approval, main): (PerpsDepositQuotePayload?, PerpsDepositQuotePayload)
        switch quote.payloads.map(\.kind) {
        case [.prebuilt]:
            return
        case [.main]:
            if quote.route == .directGateway { quote.registration = nil }
            (approval, main) = (nil, quote.payloads[0])
        case [.approval, .main]:
            if quote.route == .directGateway { quote.registration = nil }
            (approval, main) = (quote.payloads[0], quote.payloads[1])
        case [.batch]:
            let calls = try PerpsDepositCalldata.readBatch(quote.payloads[0])
            if quote.route == .directGateway, calls.count == 3, let registration = quote.registration {
                try PerpsDepositCalldata.checkKeyRegistrationCall(calls[2], registration: registration)
            } else {
                guard calls.count == 2 else {
                    throw PerpsDepositQuoteError.unexpectedPayloads(quote.payloads.map(\.payloadId))
                }
                if quote.route == .directGateway { quote.registration = nil }
            }
            (approval, main) = (calls[0], calls[1])
        default:
            throw PerpsDepositQuoteError.unexpectedPayloads(quote.payloads.map(\.payloadId))
        }
        if quote.route == .directGateway {
            try PerpsDepositCalldata.checkGatewayCall(main, beneficiary: quote.beneficiary, amountUnits: amountUnits)
        }
        guard let approval else { return }
        guard case let .token(token) = quote.sourceAsset.kind else {
            throw PerpsDepositServiceError.approvalWithoutToken(approval.payloadId)
        }
        _ = try PerpsDepositCalldata.readApproval(
            approval,
            token: token,
            spender: main.to,
            amountUnits: amountUnits,
            exactAmount: quote.route == .directGateway
        )
    }

    private func ownFunding() async throws -> [PerpsPendingFundingOperation] {
        try await journal.allFunding().filter {
            $0.belongs(walletId: walletId, walletIdentity: walletIdentity, environment: environment)
        }
    }
}

public extension PerpsDepositService {
    static func message(for error: Error) -> PerpsDepositMessage {
        switch error {
        case PerpsDepositQuoteError.belowGatewayMinimum:
            belowGatewayMinimum
        // The floor moves with the route's fees, so only the service knows it; absent when it could not price it.
        case let PerpsAPIError.badStatus(failure) where failure.reason == "amount_too_low":
            failure.minUsdAmount.map { .belowMinimum(usd: $0) } ?? belowGatewayMinimum
        // A Bitcoin source is quoted from the sender's own outputs, so the quote reads its balance.
        case let PerpsAPIError.badStatus(failure) where failure.reason == "insufficient_balance":
            .insufficientBalance
        case PerpsDepositServiceError.accountCreationPending:
            .accountCreationPending
        case let PerpsDepositServiceError.insufficientNetworkFee(symbol):
            .insufficientNetworkFee(symbol: symbol)
        case let error as PerpsAPIError where error.isAccountCreationPending:
            .accountCreationPending
        case PerpsDepositQuoteError.expired, PerpsDepositServiceError.quoteExpired, PerpsDepositServiceError.registrationRepriced,
             PerpsDepositServiceError.resumedPaymentChanged, ChainKitOperationError.quoteExpired, ChainKitOperationError.staleAuthorization:
            .quoteExpired
        case is CancellationError:
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
