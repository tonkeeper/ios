import BigInt
import ChainKit
import Foundation
import PerpsModels
import TKLogging
import TKPerpsAPI

@frozen public enum PerpsWithdrawServiceError: Error {
    case accountUnavailable
    case insufficientBalance
    case belowMinimum
    case paymentInFlight
    case quoteExpired
    /// Lighter's transfer fee is no longer the one the quote was priced with.
    case feeChanged
    case noRelayAccount
    case sendUnknown
    case sendRefused
    /// The venue refused the transaction's nonce or signature and asked for a fresh one.
    case nonceRefused
}

public struct PerpsWithdrawReview: Sendable {
    public static let provider = "Relay"

    public let destination: PerpsFundingAsset
    public let amount: String
    /// The relay pays out what the fill buys, so this is its floor.
    public let receiveAmount: String
    public let networkFee: String
    public let expiresAt: Date
    public let estimatedDurationSeconds: Int?
    let amountUnits: String
    let accountIndex: Int64
    let recipient: String
    let quote: PerpsWithdrawQuote

    /// The quote's input is a budget; only its transfer and Lighter fee are debited.
    public var debitAmount: String {
        PerpsFundingAmount.declaredAmount(units: quote.debitUnits, decimals: PerpsFundingAmount.usdcDecimals)
    }

    public func estimatedTotalFeeUsd(destinationUsdPrice: Foundation.Decimal?) -> Foundation.Decimal? {
        let locale = Locale(identifier: "en_US_POSIX")
        guard let price = destinationUsdPrice, !price.isNaN, price > 0,
              let received = Foundation.Decimal(string: receiveAmount, locale: locale), !received.isNaN, received >= 0
        else { return nil }
        let lighterFee = Foundation.Decimal(quote.feeUnits) / 1_000_000
        let spent = (Foundation.Decimal(quote.transferUnits) + Foundation.Decimal(quote.feeUnits)) / 1_000_000
        let routeFee = spent - received * price
        guard !routeFee.isNaN else { return nil }
        return max(lighterFee, routeFee)
    }
}

public actor PerpsWithdrawService {
    private let wallet: Wallet
    private let walletId: String
    private let environment: String
    private let journal: PerpsPendingJournal
    private let api: PerpsAPI
    private let accountService: PerpsAccountService
    private let recovery: PerpsFundingRecovery
    private let readOnlyToken: PerpsReadOnlyToken
    private let transferFeeUnits: @Sendable (_ accountIndex: Int64, _ toAccountIndex: Int64) async -> Int64?
    private let securityConfig: @Sendable () async -> PerpsSecurityConfig?
    private var isPaying = false

    init(
        wallet: Wallet,
        walletId: String,
        environment: String,
        journal: PerpsPendingJournal,
        api: PerpsAPI,
        accountService: PerpsAccountService,
        recovery: PerpsFundingRecovery,
        readOnlyToken: PerpsReadOnlyToken,
        transferFeeUnits: @escaping @Sendable (_ accountIndex: Int64, _ toAccountIndex: Int64) async -> Int64? = PerpsWithdrawService.lighterTransferFeeUnits,
        securityConfig: @escaping @Sendable () async -> PerpsSecurityConfig?
    ) {
        self.wallet = wallet
        self.walletId = walletId
        self.environment = environment
        self.journal = journal
        self.api = api
        self.accountService = accountService
        self.recovery = recovery
        self.readOnlyToken = readOnlyToken
        self.transferFeeUnits = transferFeeUnits
        self.securityConfig = securityConfig
    }

    public func available() async throws -> String {
        return try await PerpsOperationLog.step("available_balance", source: "backend", fields: ["flow": "withdraw", "wallet_id": walletId]) {
            let balance = try await PerpsAPIError.reissuingReadOnlyToken({ await readOnlyToken.issue() }) {
                try await api.portfolio(walletId: walletId)
            }.balance
            guard let value = balance?.transferable_balance ?? balance?.available_balance,
                  let units = try? PerpsFundingAmount.units(declaredAmount: value, decimals: PerpsFundingAmount.usdcDecimals)
            else { throw PerpsWithdrawServiceError.accountUnavailable }
            return PerpsFundingAmount.declaredAmount(units: units, decimals: PerpsFundingAmount.usdcDecimals)
        }
    }

    public func review(destination: PerpsFundingAsset, recipient: String, amount: String) async throws -> PerpsWithdrawReview {
        return try await PerpsOperationLog.step("prepare_quote", source: "client", fields: ["flow": "withdraw", "wallet_id": walletId, "asset_id": destination.assetId, "amount": amount]) {
            let accountIndex = try await accountIndex()
            let amountUnits = try PerpsFundingAmount.units(declaredAmount: amount, decimals: PerpsFundingAmount.usdcDecimals)
            guard amountUnits >= PerpsFundingAmount.gatewayMinimumUsdcUnits,
                  amountUnits <= BigUInt(Int64.max)
            else { throw PerpsWithdrawServiceError.belowMinimum }
            let availableText = try await available()
            let availableUnits = try PerpsFundingAmount.units(declaredAmount: availableText, decimals: PerpsFundingAmount.usdcDecimals)
            guard amountUnits <= availableUnits else { throw PerpsWithdrawServiceError.insufficientBalance }
            let relayAccounts = try await signedRelayAccounts()
            let quote = try await self.quote(
                destination: destination.assetId,
                recipient: recipient,
                amountUnits: amountUnits.description,
                accountIndex: accountIndex,
                relayAccounts: relayAccounts
            )
            guard let receiveUnits = BigUInt(quote.minimumOutputUnits, radix: 10) else {
                throw PerpsWithdrawQuoteError.malformed("output.min_amount")
            }
            return PerpsWithdrawReview(
                destination: destination,
                amount: PerpsFundingAmount.declaredAmount(units: amountUnits, decimals: PerpsFundingAmount.usdcDecimals),
                receiveAmount: PerpsFundingAmount.declaredAmount(units: receiveUnits, decimals: destination.decimals),
                networkFee: PerpsFundingAmount.declaredAmount(units: BigUInt(quote.feeUnits), decimals: PerpsFundingAmount.usdcDecimals),
                expiresAt: quote.expiresAt,
                estimatedDurationSeconds: quote.estimatedDurationSeconds,
                amountUnits: amountUnits.description,
                accountIndex: accountIndex,
                recipient: recipient,
                quote: quote
            )
        }
    }

    private func signedRelayAccounts() async throws -> Set<Int64> {
        guard let accounts = await securityConfig()?.relayLighterAccounts, !accounts.isEmpty else {
            PerpsOperationLog.event("relay_account", outcome: "unavailable", source: "config", fields: ["flow": "withdraw", "wallet_id": walletId])
            throw PerpsWithdrawServiceError.noRelayAccount
        }
        return accounts
    }

    private func quote(destination: String, recipient: String, amountUnits: String, accountIndex: Int64, relayAccounts: Set<Int64>) async throws -> PerpsWithdrawQuote {
        return try await PerpsOperationLog.step("quote", source: "backend", fields: ["flow": "withdraw", "wallet_id": walletId, "asset_id": destination, "amount_units": amountUnits, "account_index": String(accountIndex)]) {
            let request = Components.Schemas.WithdrawQuoteRequest(destination_asset: destination, amount: amountUnits, recipient_address: recipient)
            let requestedAt = Date()
            let response = try await api.quoteWithdraw(walletId: walletId, request: request)
            PerpsOperationLog.event("quote_response", outcome: "received", source: "backend", fields: ["quote_id": response.quote_id, "execution_id": response.tracking?.execution_id ?? "none"])

            let quote = try PerpsWithdrawQuoteReader.read(response, request: request, accountIndex: accountIndex, relayAccounts: relayAccounts, requestedAt: requestedAt)
            PerpsOperationLog.event("quote", outcome: "received", source: "backend", fields: ["quote_id": quote.quoteId, "execution_id": quote.executionId, "receive_units": quote.minimumOutputUnits, "lighter_fee_units": String(quote.feeUnits), "expires_at": String(quote.expiresAt.timeIntervalSince1970)])
            return quote
        }
    }

    @discardableResult
    private func checkRelayAccount(of shown: PerpsWithdrawQuote) async throws -> Set<Int64> {
        let relayAccounts = try await signedRelayAccounts()
        guard relayAccounts.contains(shown.toAccountIndex) else {
            PerpsOperationLog.event("relay_account", outcome: "rejected", source: "config", fields: ["quote_id": shown.quoteId, "to_account_index": String(shown.toAccountIndex)])
            throw PerpsWithdrawServiceError.quoteExpired
        }
        return relayAccounts
    }

    /// The shown quote can lapse while the passcode is typed: a renewed one is signed in its
    /// place when it pays out about what was shown, otherwise the user reviews again.
    private func signableQuote(review: PerpsWithdrawReview, shown: PerpsWithdrawQuote, renew: Bool) async throws -> PerpsWithdrawQuote {
        let relayAccounts = try await checkRelayAccount(of: shown)
        if !renew, shown.expiresAt > Date().addingTimeInterval(Self.quoteRenewalLead),
           await changedTransferFee(accountIndex: review.accountIndex, quote: shown) == nil
        {
            return shown
        }
        let renewed = try await quote(
            destination: shown.destinationAssetId,
            recipient: shown.recipient,
            amountUnits: shown.budgetUnits,
            accountIndex: review.accountIndex,
            relayAccounts: relayAccounts
        )
        guard renewed.toAccountIndex == shown.toAccountIndex else {
            PerpsOperationLog.event("quote_renewal", outcome: "rejected", source: "backend", fields: ["shown_quote_id": shown.quoteId, "quote_id": renewed.quoteId, "shown_to_account_index": String(shown.toAccountIndex), "to_account_index": String(renewed.toAccountIndex)])
            throw PerpsWithdrawQuoteError.notRelayAccount
        }
        guard renewed.feeUnits <= shown.feeUnits else {
            PerpsOperationLog.event("quote_renewal", outcome: "rejected", source: "backend", fields: ["shown_quote_id": shown.quoteId, "quote_id": renewed.quoteId, "shown_fee_units": String(shown.feeUnits), "fee_units": String(renewed.feeUnits)])
            throw PerpsWithdrawServiceError.feeChanged
        }
        guard renewed.debitUnits <= shown.debitUnits else {
            PerpsOperationLog.event("quote_renewal", outcome: "rejected", source: "backend", fields: ["shown_quote_id": shown.quoteId, "quote_id": renewed.quoteId, "shown_debit_units": String(shown.debitUnits), "debit_units": String(renewed.debitUnits)])
            throw PerpsWithdrawServiceError.quoteExpired
        }
        guard renewed.isAcceptableRenewal(of: shown) else {
            PerpsOperationLog.event("quote_renewal", outcome: "rejected", source: "backend", fields: ["shown_quote_id": shown.quoteId, "quote_id": renewed.quoteId, "shown_receive_units": shown.minimumOutputUnits, "receive_units": renewed.minimumOutputUnits])
            throw PerpsWithdrawServiceError.quoteExpired
        }
        // The signed transfer carries the quoted fee, which Lighter refuses once its own has moved.
        if let current = await changedTransferFee(accountIndex: review.accountIndex, quote: renewed) {
            PerpsOperationLog.event("transfer_fee", outcome: "changed", source: "lighter", fields: ["quoted_units": String(renewed.feeUnits), "current_units": String(current)])
            throw PerpsWithdrawServiceError.feeChanged
        }
        PerpsOperationLog.event("quote_renewal", outcome: "received", source: "backend", fields: ["shown_quote_id": shown.quoteId, "quote_id": renewed.quoteId, "shown_receive_units": shown.minimumOutputUnits, "receive_units": renewed.minimumOutputUnits])
        return renewed
    }

    private func changedTransferFee(accountIndex: Int64, quote: PerpsWithdrawQuote) async -> Int64? {
        let current = await transferFeeUnits(accountIndex, quote.toAccountIndex)
        return current.flatMap { $0 == quote.feeUnits ? nil : $0 }
    }

    static func lighterTransferFeeUnits(accountIndex: Int64, toAccountIndex: Int64) async -> Int64? {
        struct Body: Decodable {
            let transfer_fee_usdc: Int64
        }
        var url = URLComponents(string: "https://mainnet.zklighter.elliot.ai/api/v1/transferFeeInfo")!
        url.queryItems = [
            .init(name: "account_index", value: String(accountIndex)),
            .init(name: "to_account_index", value: String(toAccountIndex)),
        ]
        do {
            let (data, response) = try await URLSession.shared.data(for: URLRequest(url: url.url!, timeoutInterval: 5))
            PerpsOperationLog.event("transfer_fee", outcome: "response", source: "lighter", fields: ["http_status": String((response as? HTTPURLResponse)?.statusCode ?? 0), "account_index": String(accountIndex)])
            return try JSONDecoder().decode(Body.self, from: data).transfer_fee_usdc
        } catch {
            PerpsOperationLog.event("transfer_fee", outcome: "unavailable", source: "lighter", error: error, fields: ["account_index": String(accountIndex), "to_account_index": String(toAccountIndex)])
            return nil
        }
    }

    /// A deposit creates the account but registers no trading key, and the key is only needed
    /// to sign: until then the venue says which account this is.
    private func accountIndex() async throws -> Int64 {
        if let session = try await accountService.tradingSession(wallet: wallet) { return session.accountIndex }
        guard let index = try await api.account(walletId: walletId).account_index else {
            throw PerpsWithdrawServiceError.accountUnavailable
        }
        return Int64(index)
    }

    /// Registers the trading key with the passcode the payment was confirmed with, so a
    /// withdrawal asks for it once.
    private func tradingSession(passcode: String) async throws -> PerpsAccountSession? {
        if let session = try await accountService.tradingSession(wallet: wallet) { return session }
        switch await accountService.activate(wallet: wallet, passcode: passcode, readOnlyToken: readOnlyToken) {
        case let .active(accountIndex, apiKeyIndex, _):
            return PerpsAccountSession(accountIndex: accountIndex, apiKeyIndex: apiKeyIndex)
        case .noAccount:
            return nil
        case let .failed(error):
            throw error
        }
    }

    @discardableResult
    public func pay(review: PerpsWithdrawReview, passcode: String) async throws -> String {
        return try await PerpsOperationLog.step("payment", source: "client", fields: ["flow": "withdraw", "wallet_id": walletId, "asset_id": review.destination.assetId, "amount": review.amount]) {
            guard !isPaying else { throw PerpsWithdrawServiceError.paymentInFlight }
            isPaying = true
            defer { isPaying = false }
            try await checkRelayAccount(of: review.quote)
            let own = try await journal.allFunding().filter {
                $0.belongs(walletId: walletId, walletIdentity: wallet.id, environment: environment)
            }
            for blocking in own where blocking.withdraw?.blocksNewWithdrawal == true {
                guard let withdraw = blocking.withdraw else { continue }
                let nowMillis = Int64(Date().timeIntervalSince1970 * 1000)
                let stepExpired = withdraw.steps.last.map { $0.transactionExpiryUnixMs <= PerpsServerClock.shared.signingNowUnixMs(deviceNowUnixMs: nowMillis) } ?? false
                let nextNonce: Components.Schemas.NextNonce
                do {
                    nextNonce = try await api.nextNonce(walletId: walletId, apiKeyIndex: Int(withdraw.apiKeyIndex))
                } catch {
                    PerpsOperationLog.event("nonce", outcome: "failed", source: "backend", error: error, fields: blocking.operationLogFields)
                    throw error
                }
                guard withdraw.noncePassed(accountIndex: nextNonce.account_index, nextNonce: nextNonce.nonce) else {
                    PerpsOperationLog.event("payment", outcome: "blocked", fields: blocking.operationLogFields.merging([
                        "age_seconds": String(max(0, nowMillis - blocking.createdAtMillis) / 1000),
                        "step_expired": String(stepExpired), "next_nonce": String(nextNonce.nonce),
                        "account_matches": String(nextNonce.account_index == withdraw.accountIndex),
                    ]) { _, new in new })
                    throw PerpsWithdrawServiceError.paymentInFlight
                }
                try await accountService.submitLanes
                    .lane(for: PerpsAccountSession(accountIndex: withdraw.accountIndex, apiKeyIndex: withdraw.apiKeyIndex))
                    .advanceNonce(to: nextNonce.nonce)
            }
            for stale in own where stale.withdraw?.stage == .reviewed {
                try await journal.removeFunding(operationId: stale.operationId, expectedRevision: stale.revision)
            }
            let availableText = try await available()
            let availableUnits = try PerpsFundingAmount.units(declaredAmount: availableText, decimals: PerpsFundingAmount.usdcDecimals)
            guard let amountUnits = BigUInt(review.amountUnits, radix: 10), amountUnits <= availableUnits else {
                throw PerpsWithdrawServiceError.insufficientBalance
            }
            guard let session = try await tradingSession(passcode: passcode),
                  session.accountIndex == review.accountIndex,
                  review.quote.budgetUnits == review.amountUnits
            else { throw PerpsWithdrawServiceError.accountUnavailable }
            // A retry after a refusal gets its own relay execution, so the two withdrawals settle apart.
            let quoteUsed = own.contains { $0.withdraw?.quoteId == review.quote.quoteId && $0.withdraw?.stage != .reviewed }
            let quote = try await signableQuote(review: review, shown: review.quote, renew: quoteUsed)
            let operation = PerpsPendingFundingOperation(
                operationId: UUID().uuidString,
                walletId: walletId,
                walletIdentity: wallet.id,
                environment: environment,
                details: .withdraw(PerpsPendingWithdraw(
                    stage: .reviewed,
                    accountIndex: session.accountIndex,
                    apiKeyIndex: session.apiKeyIndex,
                    chainId: LighterConstants.shared.ChainId,
                    assetIndex: 3,
                    routeType: LighterConstants.shared.AssetRouteTypePerps,
                    amountUnits: review.amountUnits,
                    destinationAssetId: review.destination.assetId,
                    recipient: review.recipient,
                    executionId: quote.executionId,
                    quoteId: quote.quoteId,
                    quoteExpiresAtMillis: Int64(quote.expiresAt.timeIntervalSince1970 * 1000),
                    outputUnits: quote.outputUnits
                ))
            )
            let saved = try await journal.saveFundingIfAbsent(operation).operation
            // Held while this attempt runs: recovery would take a send slower than its grace
            // period for a lost one and replay it beside this one.
            await recovery.holdWithdrawal(saved.operationId)
            do {
                try await submit(saved, quote: quote, session: session, amountUnits: amountUnits, passcode: passcode)
            } catch {
                await recovery.releaseWithdrawal(saved.operationId)
                throw error
            }
            await recovery.releaseWithdrawal(saved.operationId)
            return saved.operationId
        }
    }

    private func submit(
        _ operation: PerpsPendingFundingOperation,
        quote: PerpsWithdrawQuote,
        session: PerpsAccountSession,
        amountUnits: BigUInt,
        passcode: String
    ) async throws {
        let lane = await accountService.submitLanes.lane(for: session)
        try await lane.run {
            try await submitInLane(operation, quote: quote, session: session, amountUnits: amountUnits, passcode: passcode, lane: lane)
        }
    }

    private func submitInLane(
        _ operation: PerpsPendingFundingOperation,
        quote: PerpsWithdrawQuote,
        session: PerpsAccountSession,
        amountUnits: BigUInt,
        passcode: String,
        lane: PerpsSubmitLane
    ) async throws {
        return try await PerpsOperationLog.step("submit", source: "client", fields: operation.operationLogFields) {
            var current = operation
            // The same account trades and withdraws on other devices too.
            await lane.catchUpNonce(walletId: walletId)
            let signed: PerpsSignedWithdrawal
            do {
                signed = try await PerpsOperationLog.step("sign", source: "wallet") {
                    try await accountService.signWithdrawal(
                        wallet: wallet,
                        passcode: passcode,
                        session: session,
                        amountUnits: PerpsFundingAmount.int64Units(amountUnits),
                        transfer: quote,
                        lane: lane
                    )
                }
                if quote.expiresAt <= Date() {
                    try? await PerpsOperationLog.step("nonce_resync", source: "backend") {
                        try await lane.resyncNonce(walletId: walletId)
                    }
                    throw PerpsWithdrawServiceError.quoteExpired
                }
            } catch {
                try? await PerpsOperationLog.step("journal_cleanup") {
                    try await journal.removeFunding(operationId: current.operationId, expectedRevision: current.revision)
                }
                throw error
            }
            let step = PerpsPendingSignedStep(
                stepId: UUID().uuidString,
                attemptId: UUID().uuidString,
                nonce: signed.nonce,
                transactionExpiryUnixMs: signed.expiry,
                txType: signed.txType,
                txInfo: signed.txInfo,
                txHash: signed.txHash,
                state: .signed
            )
            current = try await update(current, stage: .signed, step: step)
            current = try await update(current, stage: .sending, step: step.withState(.sending))
            do {
                try await PerpsOperationLog.step("l2_send", source: "lighter", fields: ["l2_tx_hash": step.txHash, "nonce": String(step.nonce)]) {
                    try await lane.send(walletId: walletId, txType: step.txType, txInfo: step.txInfo, txHash: step.txHash, nonce: step.nonce, operationId: current.operationId)
                }
                _ = try await update(current, stage: .accepted, step: step.withState(.accepted))
            } catch {
                PerpsOperationLog.event("submit", outcome: Self.isAmbiguousError(error) || (error as? PerpsAPIError)?.isResignRequired == true ? "unknown" : "rejected", source: "lighter", error: error, fields: current.operationLogFields)
                if let apiError = error as? PerpsAPIError, apiError.isResignRequired {
                    await lane.forgetNonce()
                    let journaled = (try? await PerpsOperationLog.step("journal_unknown") {
                        try await update(current, stage: .unknown, step: step.withState(.unknown), reason: Self.resignRequiredReason)
                    }) != nil
                    // Unrecorded, the refusal leaves the withdrawal stored as sending, which recovery may resend.
                    throw journaled ? PerpsWithdrawServiceError.nonceRefused : PerpsWithdrawServiceError.sendUnknown
                }
                if let apiError = error as? PerpsAPIError, !Self.isAmbiguous(apiError) {
                    // Refused outright, so its nonce was never used.
                    try? await PerpsOperationLog.step("nonce_resync", source: "backend") {
                        try await lane.resyncNonce(walletId: walletId)
                    }
                    _ = try await update(current, stage: .rejected, step: step.withState(.signed), reason: String(describing: error))
                    if apiError.isWithdrawalRateLimited { throw apiError }
                    throw PerpsWithdrawServiceError.sendRefused
                }
                _ = try? await PerpsOperationLog.step("journal_unknown") {
                    try await update(current, stage: .unknown, step: step.withState(.unknown))
                }
                throw PerpsWithdrawServiceError.sendUnknown
            }
        }
    }

    private func update(
        _ operation: PerpsPendingFundingOperation,
        stage: PerpsWithdrawStage,
        step: PerpsPendingSignedStep,
        reason: String? = nil
    ) async throws -> PerpsPendingFundingOperation {
        let updated = try await journal.updateFunding(operationId: operation.operationId, expectedRevision: operation.revision) { current in
            guard var withdraw = current.withdraw else { return }
            withdraw.stage = stage
            withdraw.steps = [step]
            withdraw.failureReason = reason
            current.details = .withdraw(withdraw)
        }
        await recovery.refresh()
        return updated
    }

    /// Left for signing and sending; a quote closer to its end is renewed first.
    private static let quoteRenewalLead: TimeInterval = 10
    static let resignRequiredReason = "resign_required"

    private static func isAmbiguousError(_ error: Error) -> Bool {
        guard let error = error as? PerpsAPIError else { return true }
        return isAmbiguous(error)
    }

    private static func isAmbiguous(_ error: PerpsAPIError) -> Bool {
        if error.isWithdrawalRateLimited { return false }
        return switch error {
        case .transport, .badResponse, .unknown: true
        case let .badStatus(failure): failure.retryable || failure.httpStatus >= 500
        case .unauthorized, .conflict, .notFound, .badUrl: false
        }
    }
}

public extension PerpsWithdrawService {
    static func message(for error: Error) -> PerpsWithdrawMessage {
        switch error {
        case PerpsWithdrawServiceError.belowMinimum:
            .belowMinimum(usdc: "1")
        case PerpsWithdrawServiceError.quoteExpired, PerpsWithdrawServiceError.feeChanged, PerpsWithdrawQuoteError.expired:
            .quoteExpired
        case PerpsWithdrawServiceError.noRelayAccount:
            .serviceUnavailable
        case PerpsWithdrawServiceError.nonceRefused:
            .notSent
        case PerpsWithdrawServiceError.paymentInFlight:
            .inFlight
        case let error as PerpsAPIError where error.isWithdrawalRateLimited:
            .withdrawalRateLimited
        case PerpsAPIError.transport:
            .serviceUnavailable
        case let PerpsAPIError.badStatus(failure) where failure.httpStatus >= 500:
            .serviceUnavailable
        default:
            .failed
        }
    }
}
