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
    case destinationMismatch
    case sendUnknown
    case sendRefused
}

public struct PerpsWithdrawReview: Sendable {
    public let destination: PerpsFundingAsset
    public let amount: String
    public let receiveAmount: String
    public let networkFee: String?
    public let expiresAt: Date?
    public let withdrawalDelaySeconds: Int?
    let amountUnits: String
    let accountIndex: Int64
    let recipient: String
    let quote: PerpsWithdrawQuote?

    /// A relay pays out what the fill buys, so `receiveAmount` is its floor.
    public var receivesAtLeast: Bool {
        quote != nil
    }

    /// The quote's input is a budget; only its transfer and Lighter fee are debited.
    public var debitAmount: String {
        guard let quote else { return amount }
        return PerpsFundingAmount.declaredAmount(units: BigUInt(quote.transferUnits) + BigUInt(quote.feeUnits), decimals: PerpsFundingAmount.usdcDecimals)
    }

    public func estimatedTotalFeeUsd(destinationUsdPrice: Foundation.Decimal?) -> Foundation.Decimal? {
        let locale = Locale(identifier: "en_US_POSIX")
        guard let quote else { return networkFee.flatMap { Foundation.Decimal(string: $0, locale: locale) } }
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
    private var isPaying = false

    init(wallet: Wallet, walletId: String, environment: String, journal: PerpsPendingJournal, api: PerpsAPI, accountService: PerpsAccountService) {
        self.wallet = wallet
        self.walletId = walletId
        self.environment = environment
        self.journal = journal
        self.api = api
        self.accountService = accountService
    }

    public func available() async throws -> String {
        let balance = try await PerpsAPIError.reissuingReadOnlyToken({ await accountService.refreshReadOnlyToken(wallet: wallet, force: true) }) {
            try await api.portfolio(walletId: walletId)
        }.balance
        guard let value = balance?.transferable_balance ?? balance?.available_balance,
              let units = try? PerpsFundingAmount.units(declaredAmount: value, decimals: PerpsFundingAmount.usdcDecimals)
        else { throw PerpsWithdrawServiceError.accountUnavailable }
        return PerpsFundingAmount.declaredAmount(units: units, decimals: PerpsFundingAmount.usdcDecimals)
    }

    public func review(destination: PerpsFundingAsset, recipient: String, amount: String) async throws -> PerpsWithdrawReview {
        let accountIndex = try await accountIndex()
        let amountUnits = try PerpsFundingAmount.units(declaredAmount: amount, decimals: PerpsFundingAmount.usdcDecimals)
        guard amountUnits >= PerpsFundingAmount.gatewayMinimumUsdcUnits,
              amountUnits <= BigUInt(Int64.max)
        else { throw PerpsWithdrawServiceError.belowMinimum }
        let availableText = try await available()
        let availableUnits = try PerpsFundingAmount.units(declaredAmount: availableText, decimals: PerpsFundingAmount.usdcDecimals)
        guard amountUnits <= availableUnits else { throw PerpsWithdrawServiceError.insufficientBalance }
        let direct = destination.assetId.lowercased() == PerpsFundingAssetId.usdcEthereum
        let quote: PerpsWithdrawQuote?
        let withdrawalDelaySeconds: Int?
        if direct {
            async let delaySeconds = Self.lighterWithdrawalDelaySeconds()
            let account = try await api.account(walletId: walletId)
            guard account.account_index.map(Int64.init) == accountIndex,
                  account.l1_address?.lowercased() == recipient.lowercased()
            else { throw PerpsWithdrawServiceError.destinationMismatch }
            quote = nil
            withdrawalDelaySeconds = await delaySeconds
        } else {
            let request = Components.Schemas.WithdrawQuoteRequest(
                destination_asset: destination.assetId,
                amount: amountUnits.description,
                recipient_address: recipient
            )
            let response = try await api.quoteWithdraw(walletId: walletId, request: request)
            quote = try PerpsWithdrawQuoteReader.read(response, request: request, accountIndex: accountIndex, now: Date())
            withdrawalDelaySeconds = nil
        }
        let receiveUnits = quote.flatMap { BigUInt($0.minimumOutputUnits, radix: 10) } ?? amountUnits
        let receiveAmount = PerpsFundingAmount.declaredAmount(units: receiveUnits, decimals: destination.decimals)
        return PerpsWithdrawReview(
            destination: destination,
            amount: PerpsFundingAmount.declaredAmount(units: amountUnits, decimals: PerpsFundingAmount.usdcDecimals),
            receiveAmount: receiveAmount,
            networkFee: quote.map { PerpsFundingAmount.declaredAmount(units: BigUInt($0.feeUnits), decimals: PerpsFundingAmount.usdcDecimals) } ?? "0",
            expiresAt: quote?.expiresAt,
            withdrawalDelaySeconds: withdrawalDelaySeconds,
            amountUnits: amountUnits.description,
            accountIndex: accountIndex,
            recipient: recipient,
            quote: quote
        )
    }

    private static let lighterWithdrawalDelayURL = URL(string: "https://mainnet.zklighter.elliot.ai/api/v1/withdrawalDelay")!

    private static func lighterWithdrawalDelaySeconds() async -> Int? {
        struct Body: Decodable {
            let seconds: Int
        }
        do {
            let (data, _) = try await URLSession.shared.data(for: URLRequest(url: lighterWithdrawalDelayURL, timeoutInterval: 5))
            return try JSONDecoder().decode(Body.self, from: data).seconds
        } catch {
            Log.perps.w("Withdrawal delay unavailable", error: error)
            return nil
        }
    }

    private static func lighterTransferFeeUnits(accountIndex: Int64, toAccountIndex: Int64) async -> Int64? {
        struct Body: Decodable {
            let transfer_fee_usdc: Int64
        }
        var url = URLComponents(string: "https://mainnet.zklighter.elliot.ai/api/v1/transferFeeInfo")!
        url.queryItems = [
            .init(name: "account_index", value: String(accountIndex)),
            .init(name: "to_account_index", value: String(toAccountIndex)),
        ]
        do {
            let (data, _) = try await URLSession.shared.data(for: URLRequest(url: url.url!, timeoutInterval: 5))
            return try JSONDecoder().decode(Body.self, from: data).transfer_fee_usdc
        } catch {
            Log.perps.w("Transfer fee unavailable", error: error)
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
        switch await accountService.activate(wallet: wallet, passcode: passcode) {
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
        guard !isPaying else { throw PerpsWithdrawServiceError.paymentInFlight }
        isPaying = true
        defer { isPaying = false }
        guard (review.quote?.expiresAt ?? .distantFuture) > Date() else {
            throw PerpsWithdrawServiceError.quoteExpired
        }
        // The signed transfer carries the quoted fee, which Lighter refuses once its own has moved.
        if let quote = review.quote,
           let current = await Self.lighterTransferFeeUnits(accountIndex: review.accountIndex, toAccountIndex: quote.toAccountIndex),
           current != quote.feeUnits
        {
            Log.perps.w("Withdraw fee changed quoted=\(quote.feeUnits) current=\(current)")
            throw PerpsWithdrawServiceError.feeChanged
        }
        let own = try await journal.allFunding().filter {
            $0.belongs(walletId: walletId, walletIdentity: wallet.id, environment: environment)
        }
        for blocking in own where blocking.withdraw?.blocksNewWithdrawal == true {
            guard let withdraw = blocking.withdraw else { continue }
            let nowMillis = Int64(Date().timeIntervalSince1970 * 1000)
            let stepExpired = withdraw.steps.last.map { $0.transactionExpiryUnixMs <= nowMillis } ?? false
            let nextNonce: Components.Schemas.NextNonce
            do {
                nextNonce = try await api.nextNonce(walletId: walletId, apiKeyIndex: Int(withdraw.apiKeyIndex))
            } catch {
                Log.perps.w("Withdraw nonce check failed op=\(blocking.operationId) stage=\(withdraw.stage.rawValue)", error: error)
                throw PerpsWithdrawServiceError.paymentInFlight
            }
            guard withdraw.noncePassed(accountIndex: nextNonce.account_index, nextNonce: nextNonce.nonce) else {
                Log.perps.w("Withdraw blocked op=\(blocking.operationId) stage=\(withdraw.stage.rawValue) ageSeconds=\(max(0, nowMillis - blocking.createdAtMillis) / 1000) stepExpired=\(stepExpired) relay=\(withdraw.executionId != nil) stepNonce=\(String(describing: withdraw.steps.last?.nonce)) nextNonce=\(nextNonce.nonce) accountMatches=\(nextNonce.account_index == withdraw.accountIndex)")
                throw PerpsWithdrawServiceError.paymentInFlight
            }
            try await PerpsNonceCoordinator.shared.advance(
                scope: PerpsAccountService.nonceScope(.init(accountIndex: withdraw.accountIndex, apiKeyIndex: withdraw.apiKeyIndex)),
                nextNonce: nextNonce.nonce
            )
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
              review.quote?.budgetUnits == nil || review.quote?.budgetUnits == review.amountUnits
        else { throw PerpsWithdrawServiceError.accountUnavailable }
        if review.quote == nil {
            let account = try await api.account(walletId: walletId)
            guard account.account_index.map(Int64.init) == session.accountIndex,
                  account.l1_address?.lowercased() == review.recipient.lowercased()
            else { throw PerpsWithdrawServiceError.destinationMismatch }
        }
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
                executionId: review.quote?.executionId,
                quoteId: review.quote?.quoteId,
                quoteExpiresAtMillis: review.quote.map { Int64($0.expiresAt.timeIntervalSince1970 * 1000) },
                outputUnits: review.quote?.outputUnits
            ))
        )
        let saved = try await journal.saveFundingIfAbsent(operation).operation
        // Held while this attempt runs: recovery would take a send slower than its grace
        // period for a lost one and replay it beside this one.
        let recovery = accountService.fundingRecovery(wallet: wallet)
        await recovery.holdWithdrawal(saved.operationId)
        do {
            try await submit(saved, review: review, session: session, amountUnits: amountUnits, passcode: passcode)
        } catch {
            await recovery.releaseWithdrawal(saved.operationId)
            throw error
        }
        await recovery.releaseWithdrawal(saved.operationId)
        return saved.operationId
    }

    private func submit(
        _ operation: PerpsPendingFundingOperation,
        review: PerpsWithdrawReview,
        session: PerpsAccountSession,
        amountUnits: BigUInt,
        passcode: String
    ) async throws {
        var current = operation
        let signed: PerpsSignedWithdrawal
        do {
            signed = try await accountService.signWithdrawal(
                wallet: wallet,
                passcode: passcode,
                session: session,
                amountUnits: PerpsFundingAmount.int64Units(amountUnits),
                transfer: review.quote
            )
            if let quote = review.quote, quote.expiresAt <= Date() {
                await accountService.resyncWithdrawalNonce(wallet: wallet, session: session)
                throw PerpsWithdrawServiceError.quoteExpired
            }
        } catch {
            try? await journal.removeFunding(operationId: current.operationId, expectedRevision: current.revision)
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
            let response = try await api.sendTransactions(
                walletId: walletId,
                transactions: [.init(tx_type: step.txType, tx_info: step.txInfo)]
            )
            guard response.transactions.count == 1,
                  response.transactions[0].tx_type == step.txType,
                  !PerpsExecutionRelay.normalizedHash(step.txHash).isEmpty,
                  PerpsExecutionRelay.normalizedHash(response.transactions[0].tx_hash) == PerpsExecutionRelay.normalizedHash(step.txHash)
            else {
                _ = try await update(current, stage: .unknown, step: step.withState(.unknown))
                throw PerpsWithdrawServiceError.sendUnknown
            }
            _ = try await update(current, stage: review.quote == nil ? .awaitingL1 : .accepted, step: step.withState(.accepted))
        } catch {
            if let apiError = error as? PerpsAPIError, !Self.isAmbiguous(apiError) {
                // Refused outright, so its nonce was never used.
                await accountService.resyncWithdrawalNonce(wallet: wallet, session: session)
                _ = try await update(current, stage: .rejected, step: step.withState(.signed), reason: String(describing: error))
                throw PerpsWithdrawServiceError.sendRefused
            }
            _ = try? await update(current, stage: .unknown, step: step.withState(.unknown))
            throw PerpsWithdrawServiceError.sendUnknown
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
        await accountService.fundingRecovery(wallet: wallet).refresh()
        return updated
    }

    private static func isAmbiguous(_ error: PerpsAPIError) -> Bool {
        switch error {
        case .transport, .badResponse, .unknown: true
        case let .badStatus(failure): failure.retryable || failure.httpStatus >= 500
        case .unauthorized, .conflict, .notFound, .badUrl: false
        }
    }
}
