import ChainKit
import Foundation
@testable import KeeperCore
import PerpsModels
import TKPerpsAPI
import XCTest

final class PerpsPlannerHostTests: XCTestCase {
    private func signingKey(_ host: PerpsPlannerHost) throws -> PerpsSigningKey {
        try host.signingKey(
            privateKeyHex: "0x" + String(repeating: "ab", count: 40),
            accountIndex: 42,
            chainId: 304
        )
    }

    private func scope(_ key: PerpsSigningKey) -> PerpsScope {
        PerpsScope(
            walletId: "wallet",
            venue: PerpsPlannerMapping.venue,
            chainId: 304,
            environment: "mainnet",
            accountIndex: 42,
            keyBindingId: "42/3",
            expectedPublicKey: key.publicKeyHex
        )
    }

    func testAnOpenSignsLeverageThenTheOrderAndJournalsEachStepBeforeSendingIt() async throws {
        let api = FakePerpsAPI(screens: [Fixtures.flatScreen()], nonces: [5, 6])
        let host = PerpsPlannerHost(api: api, nonceCoordinator: PerpsNonceCoordinator(), freshReadDelayNanoseconds: 1)
        let key = try signingKey(host)
        let scope = scope(key)
        let planned = try await plan(Fixtures.open(scope: scope), host: host, scope: scope)
        XCTAssertEqual(planned.plan.steps.map(\.stepId), ["leverage", "open"])

        var signed = [PerpsSignedStep]()
        try await host.execute(planned: planned, signingKey: key) { step in
            signed.append(step)
            await api.register(responseHash: step.txHash)
            await api.record("signed:\(step.stepId)")
        }

        XCTAssertEqual(signed.map(\.nonce), [5, 6])
        let nonceReads = await api.nonceReads
        XCTAssertEqual(nonceReads, 1)
        let events = await api.events
        XCTAssertEqual(events, ["signed:leverage", "send:\(signed[0].txType)", "signed:open", "send:\(signed[1].txType)"])
    }

    func testAnOpenAtTheMarketsIsolatedLeverageSignsOnlyTheOrder() async throws {
        let api = FakePerpsAPI(screens: [Fixtures.flatScreen(leverage: 10, marginMode: .isolated)], nonces: [5])
        let host = PerpsPlannerHost(api: api, nonceCoordinator: PerpsNonceCoordinator(), freshReadDelayNanoseconds: 1)
        let key = try signingKey(host)
        let scope = scope(key)
        let planned = try await plan(Fixtures.open(scope: scope), host: host, scope: scope, openInitialMarginBps: 1000)
        XCTAssertEqual(planned.plan.steps.map(\.stepId), ["open"])

        var signed = [PerpsSignedStep]()
        try await host.execute(planned: planned, signingKey: key) { step in
            signed.append(step)
            await api.register(responseHash: step.txHash)
        }

        XCTAssertEqual(signed.map(\.stepId), ["open"])
    }

    func testAnOpenSetsLeverageWhenTheMarketsSettingDiffers() async throws {
        let screens = [
            Fixtures.flatScreen(leverage: 20, marginMode: .isolated),
            Fixtures.flatScreen(leverage: 10, marginMode: .cross),
            Fixtures.flatScreen(leverage: 10, marginMode: nil),
        ]
        for screen in screens {
            let api = FakePerpsAPI(screens: [screen], nonces: [])
            let host = PerpsPlannerHost(api: api, nonceCoordinator: PerpsNonceCoordinator(), freshReadDelayNanoseconds: 1)
            let scope = try scope(signingKey(host))
            let planned = try await plan(Fixtures.open(scope: scope), host: host, scope: scope, openInitialMarginBps: 1000)
            XCTAssertEqual(planned.plan.steps.map(\.stepId), ["leverage", "open"], "\(screen)")
        }
    }

    func testPlanWidensATruncatedBookWhenTheFirstSliceHasInsufficientDepth() async throws {
        let api = FakePerpsAPI(
            screens: [Fixtures.flatScreen()],
            nonces: [5],
            books: [Fixtures.shallowBook(), Fixtures.book()]
        )
        let host = PerpsPlannerHost(api: api, nonceCoordinator: PerpsNonceCoordinator(), freshReadDelayNanoseconds: 1)
        let key = try signingKey(host)
        let scope = scope(key)

        _ = try await plan(Fixtures.open(scope: scope), host: host, scope: scope)

        let orderBookReads = await api.orderBookReads
        XCTAssertEqual(orderBookReads, 2)
    }

    func testAReplacementCancelsTheOldLegOnlyOnceTheNewOneIsResting() async throws {
        let oldLeg = Fixtures.restingTakeProfit(orderIndex: 281_474_976_710_656, clientOrderIndex: 777, trigger: "2100")
        let newLeg = Fixtures.restingTakeProfit(orderIndex: 281_474_976_710_657, clientOrderIndex: 3002, trigger: "2200")
        let api = FakePerpsAPI(
            screens: [
                Fixtures.positionScreen(orders: [oldLeg]),
                Fixtures.positionScreen(orders: [oldLeg]),
                Fixtures.positionScreen(orders: [oldLeg, newLeg]),
            ],
            nonces: [20, 21]
        )
        let host = PerpsPlannerHost(api: api, nonceCoordinator: PerpsNonceCoordinator(), freshReadDelayNanoseconds: 1)
        let key = try signingKey(host)
        let scope = scope(key)
        let planned = try await plan(Fixtures.replaceTakeProfit(scope: scope, replaced: 777, newIndex: 3002), host: host, scope: scope)
        XCTAssertEqual(planned.plan.steps.map(\.stepId), ["autoClose", "cancelTakeProfit"])

        var signed = [PerpsSignedStep]()
        try await host.execute(planned: planned, signingKey: key) {
            signed.append($0)
            await api.register(responseHash: $0.txHash)
        }

        XCTAssertEqual(signed.map(\.stepId), ["autoClose", "cancelTakeProfit"])
        XCTAssertEqual(signed.map(\.nonce), [20, 21])
        XCTAssertEqual(Set(signed.map(\.planDigest)).count, 1)
        let reads = await api.tradingScreenReads
        XCTAssertEqual(reads, 3)
    }

    func testOneHostKeepsTheOptimisticCursorAcrossExecutions() async throws {
        let api = FakePerpsAPI(screens: [Fixtures.flatScreen()], nonces: [5])
        let host = PerpsPlannerHost(api: api, nonceCoordinator: PerpsNonceCoordinator(), freshReadDelayNanoseconds: 1)
        let key = try signingKey(host)
        let scope = scope(key)
        let firstPlan = try await plan(Fixtures.open(scope: scope), host: host, scope: scope)
        let secondPlan = try await plan(Fixtures.open(scope: scope), host: host, scope: scope)

        var signed = [PerpsSignedStep]()
        try await host.execute(planned: firstPlan, signingKey: key) {
            signed.append($0)
            await api.register(responseHash: $0.txHash)
        }
        try await host.execute(planned: secondPlan, signingKey: key) {
            signed.append($0)
            await api.register(responseHash: $0.txHash)
        }

        XCTAssertEqual(signed.map(\.nonce), [5, 6, 7, 8])
        let nonceReads = await api.nonceReads
        XCTAssertEqual(nonceReads, 1)
    }

    func testContextUsesTheWalletIntegratorFeesReturnedByTheAPI() async throws {
        let api = FakePerpsAPI(
            screens: [Fixtures.flatScreen()],
            nonces: [5],
            integrator: Fixtures.integrator()
        )
        let host = PerpsPlannerHost(api: api, nonceCoordinator: PerpsNonceCoordinator(), freshReadDelayNanoseconds: 1)

        let context = try await host.context(
            walletId: "wallet",
            marketId: 1,
            scope: .init(
                walletId: "wallet",
                venue: PerpsPlannerMapping.venue,
                chainId: 304,
                environment: "mainnet",
                accountIndex: 42,
                keyBindingId: "42/3",
                expectedPublicKey: "0xpublic"
            ),
            environment: "mainnet",
            liveMark: nil
        )

        XCTAssertEqual(context.rules.integrator.accountIndex, 745_796)
        XCTAssertEqual(context.rules.integrator.open.takerFeePpm, 900)
        XCTAssertEqual(context.rules.integrator.open.makerFeePpm, 700)
        XCTAssertEqual(context.rules.integrator.close.takerFeePpm, 900)
        XCTAssertEqual(context.rules.integrator.takeProfit.makerFeePpm, 700)
        XCTAssertEqual(context.rules.integrator.stopLoss.takerFeePpm, 900)
        let integratorReads = await api.integratorReads
        XCTAssertEqual(integratorReads, 1)
    }

    func testMarketSnapshotIncludesTheIntegratorTakerFeeInBookCoverage() async throws {
        let api = FakePerpsAPI(
            screens: [Fixtures.flatScreen()],
            nonces: [5],
            integrator: Fixtures.integrator()
        )
        let host = PerpsPlannerHost(api: api, nonceCoordinator: PerpsNonceCoordinator(), freshReadDelayNanoseconds: 1)
        let key = try signingKey(host)
        let scope = scope(key)

        _ = try await plan(Fixtures.open(scope: scope), host: host, scope: scope)

        let feeRate = await api.feeRates.first
        XCTAssertEqual(feeRate, "0.0013")
    }

    func testACloseAsksForABookSliceCoveringTwiceThePositionNotional() async throws {
        let api = FakePerpsAPI(screens: [Fixtures.positionScreen(orders: [])], nonces: [5])
        let host = PerpsPlannerHost(api: api, nonceCoordinator: PerpsNonceCoordinator(), freshReadDelayNanoseconds: 1)
        let key = try signingKey(host)
        let scope = scope(key)

        _ = try await plan(Fixtures.close(scope: scope), host: host, scope: scope)

        let notionals = await api.notionals
        XCTAssertEqual(notionals, ["4000"])
    }

    func testAResignRequestIsAnsweredOnceWithAFreshNonce() async throws {
        let refused = PerpsAPIError.badStatus(
            PerpsAPIFailure(httpStatus: 400, code: "validation_error", message: nil, retryable: false, reason: "resign_required")
        )
        let api = FakePerpsAPI(screens: [Fixtures.flatScreen()], nonces: [5, 12, 20], sendRefusals: [refused])
        let host = PerpsPlannerHost(api: api, nonceCoordinator: PerpsNonceCoordinator(), freshReadDelayNanoseconds: 1)
        let key = try signingKey(host)
        let scope = scope(key)
        let planned = try await plan(Fixtures.open(scope: scope), host: host, scope: scope)

        var signed = [PerpsSignedStep]()
        try await host.execute(planned: planned, signingKey: key) {
            signed.append($0)
            await api.register(responseHash: $0.txHash)
        }

        XCTAssertEqual(signed.map(\.nonce), [5, 12, 13])
        let nonceReads = await api.nonceReads
        XCTAssertEqual(nonceReads, 2)
        let sends = await api.sendCount
        XCTAssertEqual(sends, 3)
    }

    func testAnAmbiguousRelayFailureIsNotRetried() async throws {
        let refused = PerpsAPIError.transport(underlying: nil)
        let api = FakePerpsAPI(screens: [Fixtures.flatScreen()], nonces: [5, 12], sendRefusals: [refused])
        let host = PerpsPlannerHost(api: api, nonceCoordinator: PerpsNonceCoordinator(), freshReadDelayNanoseconds: 1)
        let key = try signingKey(host)
        let scope = scope(key)
        let planned = try await plan(Fixtures.open(scope: scope), host: host, scope: scope)

        var signed = [PerpsSignedStep]()
        do {
            try await host.execute(planned: planned, signingKey: key) { step in
                if !signed.contains(where: { $0.attemptId == step.attemptId }) {
                    signed.append(step)
                    await api.register(responseHash: step.txHash)
                }
            }
            XCTFail("an ambiguous relay failure must be surfaced")
        } catch let error as PerpsTradingError {
            guard case .serverUnavailable = error else { return XCTFail("unexpected \(error)") }
        }

        XCTAssertEqual(signed.map(\.nonce), [5])
        let nonceReads = await api.nonceReads
        XCTAssertEqual(nonceReads, 1)
        let sends = await api.sendCount
        XCTAssertEqual(sends, 1)
    }

    func testAnIntegratorRefusalIsKeptForTheCallerAndNotRetried() async throws {
        let refused = PerpsAPIError.badStatus(
            PerpsAPIFailure(httpStatus: 400, code: "validation_error", message: nil, retryable: false, reason: "integrator_not_approved")
        )
        let api = FakePerpsAPI(screens: [Fixtures.flatScreen()], nonces: [5], sendRefusals: [refused])
        let nonceCoordinator = PerpsNonceCoordinator()
        let host = PerpsPlannerHost(api: api, nonceCoordinator: nonceCoordinator, freshReadDelayNanoseconds: 1)
        let key = try signingKey(host)
        let scope = scope(key)
        let planned = try await plan(Fixtures.open(scope: scope), host: host, scope: scope)
        let relay = PerpsExecutionRelay(api: api, nonceCoordinator: nonceCoordinator, persistState: { _, _ in })

        do {
            try await host.execute(planned: planned, signingKey: key, execution: relay)
            XCTFail("a refusal for a missing integrator approval must be surfaced")
        } catch let error as PerpsTradingError {
            guard case .serverRejected = error else { return XCTFail("unexpected \(error)") }
        }

        XCTAssertTrue(relay.integratorNotApproved)
        let sends = await api.sendCount
        XCTAssertEqual(sends, 1)
    }

    func testARelayAnswerWithoutATransactionIsAProtocolFailure() async throws {
        let api = FakePerpsAPI(screens: [Fixtures.flatScreen()], nonces: [5], emptySendResponses: true)
        let host = PerpsPlannerHost(api: api, nonceCoordinator: PerpsNonceCoordinator(), freshReadDelayNanoseconds: 1)
        let key = try signingKey(host)
        let scope = scope(key)
        let planned = try await plan(Fixtures.open(scope: scope), host: host, scope: scope)

        do {
            try await host.execute(planned: planned, signingKey: key) { step in
                await api.register(responseHash: step.txHash)
            }
            XCTFail("an empty relay answer must not count as a send")
        } catch let error as PerpsTradingError {
            guard case .protocolFailure = error else { return XCTFail("unexpected \(error)") }
        }
        let sends = await api.sendCount
        XCTAssertEqual(sends, 1)
    }

    func testARelayAnswerWithAnotherTransactionHashIsAProtocolFailure() async throws {
        let api = FakePerpsAPI(screens: [Fixtures.flatScreen()], nonces: [5])
        let host = PerpsPlannerHost(api: api, nonceCoordinator: PerpsNonceCoordinator(), freshReadDelayNanoseconds: 1)
        let key = try signingKey(host)
        let scope = scope(key)
        let planned = try await plan(Fixtures.open(scope: scope), host: host, scope: scope)

        do {
            try await host.execute(planned: planned, signingKey: key) { _ in }
            XCTFail("a relay answer for another transaction must not count as a send")
        } catch let error as PerpsTradingError {
            guard case .protocolFailure = error else { return XCTFail("unexpected \(error)") }
        }
        let sends = await api.sendCount
        XCTAssertEqual(sends, 1)
    }

    /// Every quote reads the screen, and without the token it is refused outright.
    func testAScreenRefusedForAMissingReadOnlyTokenIsReadAgainOnceOneIsIssued() async throws {
        let missing = PerpsAPIFailure(httpStatus: 400, code: "readonly_token_unavailable", message: nil, retryable: false, reason: nil)
        let api = FakePerpsAPI(screens: [Fixtures.flatScreen()], nonces: [], screenRefusals: [PerpsAPIError.badStatus(missing)])
        let host = PerpsPlannerHost(api: api, nonceCoordinator: PerpsNonceCoordinator(), freshReadDelayNanoseconds: 1) {
            await api.record("reissue")
            return true
        }
        let key = try signingKey(host)

        _ = try await host.context(walletId: "wallet", marketId: 1, scope: scope(key), environment: "mainnet", liveMark: nil)

        let events = await api.events
        let reads = await api.tradingScreenReads
        XCTAssertEqual(events, ["reissue"])
        XCTAssertEqual(reads, 2)
    }

    func testABookMoreThanAMinuteAheadOfTheDeviceClockIsADeviceClockSkew() async {
        let error = await planError(
            book: Fixtures.book(updatedAt: Date().addingTimeInterval(90)),
            clock: PerpsServerClock()
        )

        XCTAssertEqual(error as? PerpsTradingError, .deviceClockSkew)
    }

    func testAClockSecondsOffTheServerStillPlans() async {
        for skew: TimeInterval in [-30, 30] {
            let clock = PerpsServerClock()
            clock.record(serverDate: Date().addingTimeInterval(skew))

            let error = await planError(book: Fixtures.book(updatedAt: Date().addingTimeInterval(skew)), clock: clock)

            XCTAssertNil(error, "skew \(skew)")
        }
    }

    func testAMarketContextOffTheServerClockByMoreThanAMinuteIsADeviceClockSkew() async throws {
        for skew: TimeInterval in [-90, 90] {
            let clock = PerpsServerClock()
            clock.record(serverDate: Date().addingTimeInterval(skew))
            let api = FakePerpsAPI(screens: [Fixtures.flatScreen()], nonces: [])
            let host = PerpsPlannerHost(api: api, nonceCoordinator: PerpsNonceCoordinator(), serverClock: clock)
            let scope = try scope(signingKey(host))

            do {
                _ = try await host.context(walletId: "wallet", marketId: 1, scope: scope, environment: "mainnet", liveMark: nil)
                XCTFail("skew \(skew) planned")
            } catch {
                XCTAssertEqual(error as? PerpsTradingError, .deviceClockSkew, "skew \(skew)")
            }
        }
    }

    func testATradeOnAClockAheadOfTheServerExpiresByServerTime() async throws {
        let clock = PerpsServerClock()
        clock.record(serverDate: Date().addingTimeInterval(-30))
        let api = FakePerpsAPI(
            screens: [Fixtures.flatScreen()],
            nonces: [5, 6],
            books: [Fixtures.book(updatedAt: Date().addingTimeInterval(-30))]
        )
        let host = PerpsPlannerHost(api: api, nonceCoordinator: PerpsNonceCoordinator(), freshReadDelayNanoseconds: 1, serverClock: clock)
        let key = try signingKey(host)
        let scope = scope(key)
        let planned = try await plan(Fixtures.open(scope: scope), host: host, scope: scope)

        var expiries = [Int64]()
        try await host.execute(planned: planned, signingKey: key) { step in
            expiries.append(step.transactionExpiryUnixMs)
            await api.register(responseHash: step.txHash)
        }

        let serverExpiry = PerpsPlannerMapping.nowUnixMs() - 30000 + LighterConstants.shared.DefaultExpireTimeMillis
        XCTAssertEqual(expiries.count, 2)
        for expiry in expiries {
            XCTAssertLessThanOrEqual(expiry, serverExpiry)
            XCTAssertGreaterThan(expiry, serverExpiry - 5000)
        }
    }

    func testAQuietBookOnACorrectClockPlans() async {
        let clock = PerpsServerClock()
        clock.record(serverDate: Date())

        let error = await planError(book: Fixtures.book(updatedAt: Date().addingTimeInterval(-1200)), clock: clock)

        XCTAssertNil(error)
    }

    private func planError(book: Components.Schemas.TruncatedOrderBook, clock: PerpsServerClock) async -> Error? {
        let api = FakePerpsAPI(screens: [Fixtures.flatScreen()], nonces: [5], books: [book])
        let host = PerpsPlannerHost(
            api: api,
            nonceCoordinator: PerpsNonceCoordinator(),
            freshReadDelayNanoseconds: 1,
            serverClock: clock
        )
        do {
            let scope = try scope(signingKey(host))
            _ = try await plan(Fixtures.open(scope: scope), host: host, scope: scope)
            return nil
        } catch {
            return error
        }
    }

    private func plan(
        _ intent: PerpsTradeIntent,
        host: PerpsPlannerHost,
        scope: PerpsScope,
        openInitialMarginBps: Int32? = nil
    ) async throws -> PerpsPlannedTrade {
        let context = try await host.context(
            walletId: "wallet",
            marketId: 1,
            scope: scope,
            environment: "mainnet",
            liveMark: nil,
            openInitialMarginBps: openInitialMarginBps
        )
        return try await host.plan(intent: intent, context: context)
    }
}

private actor FakePerpsAPI: PerpsAPI {
    struct Unsupported: Error {}

    private var screens: [Components.Schemas.TradingScreen]
    private var screenRefusals: [Error]
    private var nonces: [Int64]
    private var sendRefusals: [Error]
    private let emptySendResponses: Bool
    private(set) var events = [String]()
    private(set) var tradingScreenReads = 0
    private(set) var integratorReads = 0
    private(set) var nonceReads = 0
    private(set) var sendCount = 0
    private var responseHashes = [String]()
    private var books: [Components.Schemas.TruncatedOrderBook]
    private(set) var orderBookReads = 0
    private(set) var feeRates = [String]()
    private(set) var notionals = [String]()
    private let integratorConfig: Components.Schemas.Integrator

    init(
        screens: [Components.Schemas.TradingScreen],
        nonces: [Int64],
        screenRefusals: [Error] = [],
        sendRefusals: [Error] = [],
        emptySendResponses: Bool = false,
        books: [Components.Schemas.TruncatedOrderBook] = [Fixtures.book()],
        integrator: Components.Schemas.Integrator = .init(
            integrator_account_index: 0,
            integrator_taker_fee: 0,
            integrator_maker_fee: 0,
            max_perps_taker_fee: 0,
            max_perps_maker_fee: 0,
            max_spot_taker_fee: 0,
            max_spot_maker_fee: 0,
            approval_ttl_ms: 0
        )
    ) {
        self.screens = screens
        self.screenRefusals = screenRefusals
        self.nonces = nonces
        self.sendRefusals = sendRefusals
        self.emptySendResponses = emptySendResponses
        self.books = books
        integratorConfig = integrator
    }

    func record(_ event: String) {
        events.append(event)
    }

    func account(walletId: String) async throws -> Components.Schemas.Account {
        throw Unsupported()
    }

    func integrator(walletId: String) async throws -> Components.Schemas.Integrator {
        integratorReads += 1
        return integratorConfig
    }

    func bindAccount(
        walletId: String,
        request: Components.Schemas.BindAccountRequest
    ) async throws -> Components.Schemas.Account {
        throw Unsupported()
    }

    func register(responseHash: String) {
        responseHashes.append(responseHash)
    }

    func tradingScreen(walletId: String, marketId: Int64) async throws -> Components.Schemas.TradingScreen {
        tradingScreenReads += 1
        if !screenRefusals.isEmpty { throw screenRefusals.removeFirst() }
        return screens.count > 1 ? screens.removeFirst() : screens[0]
    }

    func truncatedOrderBook(
        walletId: String,
        marketId: Int64,
        side: Operations.getTruncatedOrderBook.Input.Query.sidePayload,
        feeRate: String,
        notional: String
    ) async throws -> Components.Schemas.TruncatedOrderBook {
        orderBookReads += 1
        feeRates.append(feeRate)
        notionals.append(notional)
        return books.count > 1 ? books.removeFirst() : books[0]
    }

    func issueReadOnlyToken(
        walletId _: String,
        lighterAuth _: String
    ) async throws -> Components.Schemas.IssuedRoToken {
        throw PerpsAPIError.unauthorized
    }

    func nextNonce(walletId: String, apiKeyIndex: Int) async throws -> Components.Schemas.NextNonce {
        nonceReads += 1
        return .init(account_index: 42, nonce: nonces.count > 1 ? nonces.removeFirst() : nonces[0])
    }

    func sendTransactions(
        walletId: String,
        transactions: [Components.Schemas.SignedTransaction]
    ) async throws -> Components.Schemas.SendTransactionsResponse {
        sendCount += 1
        let hashes = transactions.map { _ in
            responseHashes.isEmpty ? "hash-\(sendCount)" : responseHashes.removeFirst()
        }
        if !sendRefusals.isEmpty {
            throw sendRefusals.removeFirst()
        }
        events.append(contentsOf: transactions.map { "send:\($0.tx_type)" })
        if emptySendResponses {
            return .init(transactions: [])
        }
        return .init(transactions: zip(transactions, hashes).map { .init(tx_type: $0.0.tx_type, tx_hash: $0.1) })
    }

    func openDeposit(
        walletId _: String,
        request _: Components.Schemas.OpenDepositRequest
    ) async throws -> Components.Schemas.Deposit {
        throw Unsupported()
    }

    func getDeposit(walletId _: String, depositId _: String) async throws -> Components.Schemas.Deposit {
        throw Unsupported()
    }

    func quoteDeposit(
        walletId _: String,
        request _: Components.Schemas.DepositQuoteRequest
    ) async throws -> Components.Schemas.DepositQuote {
        throw Unsupported()
    }

    func quoteWithdraw(walletId _: String, request _: Components.Schemas.WithdrawQuoteRequest) async throws -> Components.Schemas.WithdrawQuote {
        throw Unsupported()
    }

    func getFundingStatus(
        walletId _: String,
        executionId _: String
    ) async throws -> Components.Schemas.FundingStatus {
        throw Unsupported()
    }

    func portfolio(walletId: String) async throws -> Components.Schemas.Portfolio {
        throw Unsupported()
    }

    func listOpenPositions(walletId _: String) async throws -> Components.Schemas.OpenPositionsPage {
        throw Unsupported()
    }

    func getOrder(walletId _: String, id _: String) async throws -> Components.Schemas.OrderDetail {
        throw Unsupported()
    }

    func getOpenPosition(walletId: String, id: String) async throws -> Components.Schemas.OpenPositionDetail {
        throw Unsupported()
    }

    func positionState(walletId: String, id: String, clientOrderIndex: Int64?) async throws -> Components.Schemas.PositionState {
        throw Unsupported()
    }

    func accountTier(walletId _: String) async throws -> Components.Schemas.AccountTier {
        throw Unsupported()
    }

    func changeAccountTier(walletId _: String, lighterAuth _: String, newTier _: String) async throws {
        throw Unsupported()
    }

    func withdrawals(walletId _: String, cursor _: String?) async throws -> Components.Schemas.ActivityPage {
        throw Unsupported()
    }
}

private enum Fixtures {
    static func integrator() -> Components.Schemas.Integrator {
        .init(
            integrator_account_index: 745_796,
            integrator_taker_fee: 900,
            integrator_maker_fee: 700,
            max_perps_taker_fee: 1000,
            max_perps_maker_fee: 800,
            max_spot_taker_fee: 0,
            max_spot_maker_fee: 0,
            approval_ttl_ms: 31_536_000_000
        )
    }

    static func market() -> Components.Schemas.Market {
        .init(
            market_index: 1,
            symbol: "ETH",
            quote_asset: "USDC",
            status: "active",
            price_decimals: 2,
            size_decimals: 4,
            tick_size: "0.01",
            step_size: "0.0001",
            min_size_base: "0.001",
            maker_fee_pct: "0.02",
            taker_fee_pct: "0.04",
            initial_margin_fraction: 400,
            maintenance_margin_fraction: 300,
            mark_price: "2000"
        )
    }

    static func flatScreen(
        leverage: Int? = nil,
        marginMode: Components.Schemas.MarginMode? = nil
    ) -> Components.Schemas.TradingScreen {
        .init(
            market: market(),
            position: nil,
            open_orders: [],
            balance: .init(available_balance: "1000"),
            leverage: leverage,
            margin_mode: marginMode.map { .init(value1: $0) },
            flags: .init(open_enabled: true, cancel_enabled: true)
        )
    }

    static func positionScreen(orders: [Components.Schemas.Order]) -> Components.Schemas.TradingScreen {
        .init(
            market: market(),
            position: .init(value1: .init(
                market_index: 1,
                symbol: "ETH",
                side: .long,
                size: "1",
                avg_entry_price: "1900",
                liquidation_price: "1700",
                margin_mode: .isolated,
                allocated_margin: "200",
                leverage: 10
            )),
            open_orders: orders,
            balance: .init(available_balance: "1000"),
            flags: .init(open_enabled: true, cancel_enabled: true)
        )
    }

    static func restingTakeProfit(orderIndex: Int64, clientOrderIndex: Int64, trigger: String) -> Components.Schemas.Order {
        .init(
            order_index: orderIndex,
            client_order_index: clientOrderIndex,
            market_index: 1,
            side: .short,
            _type: .market,
            status: .open,
            category: .take_profit,
            base_size: "0",
            filled_base: "0",
            trigger_price: trigger,
            reduce_only: true
        )
    }

    static func book(updatedAt: Date = Date()) -> Components.Schemas.TruncatedOrderBook {
        .init(
            updated_at: updatedAt,
            truncated: true,
            bids: [.init(price: "1999", size: "10")],
            asks: [.init(price: "2000", size: "10")]
        )
    }

    static func shallowBook() -> Components.Schemas.TruncatedOrderBook {
        .init(
            updated_at: Date(),
            truncated: true,
            bids: [.init(price: "1999", size: "0.001")],
            asks: [.init(price: "2000", size: "0.001")]
        )
    }

    static func open(scope: PerpsScope) -> PerpsTradeIntent {
        PerpsTradeIntent.Open(
            operationId: "op-open",
            scope: scope,
            marketId: 1,
            side: PerpsSide.long_,
            marginBudgetQuote: 100_000_000,
            initialMarginBps: 1000,
            clientOrderIndex: 1001,
            order: PerpsOrderSpec.Market(maxSlippagePpm: KotlinLong(value: 10000), slippageUtilizationPpm: 0, marginSafetyBufferPpm: 0),
            autoClose: nil
        )
    }

    static func close(scope: PerpsScope) -> PerpsTradeIntent {
        PerpsTradeIntent.Close(
            operationId: "op-close",
            scope: scope,
            marketId: 1,
            positionId: PerpsPlannerMapping.positionId(marketId: 1),
            side: PerpsSide.long_,
            positionBaseAmount: 10000,
            baseAmount: nil,
            maxSlippagePpm: KotlinLong(value: 10000),
            clientOrderIndex: 1002,
            autoClose: nil
        )
    }

    static func replaceTakeProfit(scope: PerpsScope, replaced: Int64, newIndex: Int64) -> PerpsTradeIntent {
        let now = PerpsPlannerMapping.nowUnixMs()
        return PerpsTradeIntent.AutoClose(
            operationId: "op-protect",
            scope: scope,
            marketId: 1,
            positionId: "1",
            side: PerpsSide.long_,
            autoClose: PerpsAutoCloseSpec(
                takeProfit: PerpsAutoCloseLeg(
                    triggerPrice: 220_000,
                    maxSlippagePpm: nil,
                    expiryUnixMs: now + 86_400_000,
                    clientOrderIndex: newIndex
                ),
                stopLoss: nil,
                replacedTakeProfitOrderIndex: KotlinLong(value: replaced),
                replacedStopLossOrderIndex: nil
            )
        )
    }
}
