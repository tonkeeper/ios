import Foundation
@testable import KeeperCore
import PerpsModels
import TKPerpsAPI
import TonSwift
import XCTest

private final class WatchFocusBox: @unchecked Sendable {
    private let lock = NSLock()
    private var focus = PerpsWatchFocus.idle

    var value: PerpsWatchFocus {
        get { lock.withLock { focus } }
        set { lock.withLock { focus = newValue } }
    }
}

/// Counts portfolio reads and, once armed, lets the next status probe wait for one to start.
private final class StatusPortfolioProbe: @unchecked Sendable {
    private let lock = NSLock()
    private var portfolioReads = 0
    private var readsWhenArmed: Int?
    private(set) var portfolioDuringStatus: Bool?

    func portfolioRead() {
        lock.withLock { portfolioReads += 1 }
    }

    func arm() {
        lock.withLock { readsWhenArmed = portfolioReads }
    }

    func statusRead() async {
        let start: Int? = lock.withLock {
            defer { readsWhenArmed = nil }
            return readsWhenArmed
        }
        guard let start else { return }
        for _ in 0 ..< 100 where lock.withLock({ portfolioReads }) == start {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        let seen = lock.withLock { portfolioReads > start }
        lock.withLock { portfolioDuringStatus = seen }
    }
}

final class PerpsAccountStatusMappingTests: XCTestCase {
    func testARefreshOfAnActiveAccountReadsThePortfolioAlongsideTheStatus() async throws {
        let probe = StatusPortfolioProbe()
        let api = AccountStubAPI(
            account: .init(account_index: 42, has_l2_key: true, has_ro_token: true, available_balance: "75"),
            balance: .init(available_balance: "75"),
            onPortfolio: { probe.portfolioRead() },
            onAccount: { await probe.statusRead() }
        )
        let store = PerpsAccountStore(service: PerpsTkAccountReading(api: api), wallet: makeWallet())
        let loaded = expectation(description: "active with positions")
        loaded.assertForOverFulfill = false
        store.addObserver(self) { _, event in
            if case let .didUpdate(.active(account)) = event, account.positionsLoaded {
                loaded.fulfill()
            }
        }
        store.resolveIfNeeded()
        await fulfillment(of: [loaded], timeout: 2)

        probe.arm()
        store.refresh()
        for _ in 0 ..< 300 where probe.portfolioDuringStatus == nil {
            try await Task.sleep(nanoseconds: 10_000_000)
        }

        XCTAssertEqual(probe.portfolioDuringStatus, true, "the portfolio waited for the status probe")
    }

    func testFundingRefreshDoesNotReuseThePortfolioFromBeforeTheDebit() async throws {
        let reads = PerpsSharedReads<String, PerpsPortfolioRead>(
            reuseWindow: 1,
            now: { Date(timeIntervalSince1970: 1_700_000_000) }
        )
        _ = try await reads.value(for: "perps-multichain-wallet") {
            PerpsPortfolioRead(
                portfolio: .init(balance: .init(available_balance: "100"), positions: [], open_orders: []),
                requestedAt: ProcessInfo.processInfo.systemUptime
            )
        }
        let api = AccountStubAPI(
            account: .init(account_index: 42, has_l2_key: true, has_ro_token: true, available_balance: "75"),
            balance: .init(available_balance: "75")
        )
        let store = PerpsAccountStore(
            service: PerpsTkAccountReading(api: api, portfolioReads: reads),
            wallet: makeWallet()
        )
        let loaded = expectation(description: "portfolio after withdrawal")
        loaded.assertForOverFulfill = false
        store.addObserver(self) { _, event in
            if case let .didUpdate(.active(account)) = event, account.positionsLoaded {
                loaded.fulfill()
            }
        }

        store.applyFundingState(.loaded([PerpsPendingFundingOperation(
            operationId: "withdraw", walletId: "perps-wallet", walletIdentity: "identity", environment: "test",
            details: .withdraw(PerpsPendingWithdraw(
                stage: .accepted, accountIndex: 42, apiKeyIndex: 1, chainId: 304,
                assetIndex: 0, routeType: 0, amountUnits: "25000000"
            ))
        )]))

        await fulfillment(of: [loaded], timeout: 2)
        guard case let .active(account) = store.currentWalletState() else { return XCTFail("expected active account") }
        XCTAssertEqual(account.availableBalance, "75")
    }

    func testPortfolioKeepsTransferableSeparateFromAvailable() async throws {
        for transferable in ["7.25", nil] as [String?] {
            let api = AccountStubAPI(account: .init(), balance: .init(
                available_balance: "100", transferable_balance: transferable
            ))
            let snapshot = try await PerpsTkAccountReading(api: api).portfolio(wallet: makeWallet())
            XCTAssertEqual(snapshot?.availableBalance, "100")
            XCTAssertEqual(snapshot?.transferableBalance, transferable)
        }
    }

    func testPortfolioOrdersCarryTheLeverageAndMarginTheBackendSends() async throws {
        let order = Components.Schemas.Order(
            order_index: 21,
            market_index: 1,
            symbol: "ZEC",
            side: .long,
            _type: .limit,
            category: .open,
            base_size: "0.1",
            price: "105.4"
        )
        let api = AccountStubAPI(
            account: .init(),
            balance: .init(available_balance: "100"),
            openOrders: [
                .init(value1: order, value2: .init(leverage: 3, margin: "3.5")),
                .init(value1: order, value2: .init()),
            ]
        )

        let snapshot = try await PerpsTkAccountReading(api: api).portfolio(wallet: makeWallet())

        let orders = try XCTUnwrap(snapshot?.openOrders)
        XCTAssertEqual(orders.map(\.leverage), [3, nil])
        XCTAssertEqual(orders.map(\.marginUsd), [3.5, nil])
    }

    func testPortfolioWithoutReadOnlyTokenSurfacesTheRefusal() async {
        let api = AccountStubAPI(
            account: .init(),
            balance: .init(equity: "120", available_balance: "100", transferable_balance: "80"),
            portfolioError: .badStatus(.init(
                httpStatus: 400,
                code: "readonly_token_unavailable",
                message: nil,
                retryable: false,
                reason: nil
            )),
            positions: [.init(market_index: 1, symbol: "BTC", size: "0.1")]
        )

        do {
            _ = try await PerpsTkAccountReading(api: api).portfolio(wallet: makeWallet())
            XCTFail("a refused portfolio must not be replaced by another read")
        } catch let error as PerpsAPIError {
            XCTAssertTrue(error.isReadOnlyTokenUnavailable)
        } catch {
            XCTFail("unexpected error \(error)")
        }
    }

    func testPositionsWatchKeepsPollingWhenThePortfolioNeedsAToken() async {
        let api = AccountStubAPI(
            account: .init(),
            portfolioError: .badStatus(.init(
                httpStatus: 400,
                code: "readonly_token_unavailable",
                message: nil,
                retryable: false,
                reason: nil
            )),
            positions: [.init(market_index: 1, symbol: "BTC", size: "0.1")]
        )
        let updated = expectation(description: "positions read without a token")
        updated.expectedFulfillmentCount = 2
        updated.assertForOverFulfill = false
        let reading = PerpsTkAccountReading(api: api)
        let watch = reading.watchPositions(
            wallet: makeWallet(),
            pollInterval: 0.5,
            focus: { .portfolio },
            onUpdate: { tick in
                guard case let .positions(positions, _) = tick, positions.map(\.marketId) == [1] else { return }
                updated.fulfill()
            },
            onInterrupted: { XCTFail("the positions read should use the fallback") }
        )

        await fulfillment(of: [updated], timeout: 2)
        withExtendedLifetime(reading) { watch.cancel() }
    }

    func testThePositionsPollCarriesThePortfolioWithItsBalance() async {
        let api = AccountStubAPI(
            account: .init(),
            balance: .init(available_balance: "90", transferable_balance: "80"),
            openOrders: [.init(
                value1: .init(
                    order_index: 21,
                    market_index: 1,
                    symbol: "BTC",
                    side: .long,
                    _type: .limit,
                    category: .open,
                    base_size: "0.0003",
                    price: "80000"
                ),
                value2: .init()
            )]
        )
        let updated = expectation(description: "orders and balance read with the positions")
        updated.assertForOverFulfill = false
        let reading = PerpsTkAccountReading(api: api)
        let watch = reading.watchPositions(
            wallet: makeWallet(),
            pollInterval: 0.5,
            focus: { .portfolio },
            onUpdate: { tick in
                guard case let .portfolio(snapshot) = tick,
                      snapshot.openOrders.map(\.order.orderIndex) == [21],
                      snapshot.availableBalance == "90",
                      snapshot.transferableBalance == "80"
                else { return }
                updated.fulfill()
            },
            onInterrupted: { XCTFail("the portfolio read should succeed") }
        )

        await fulfillment(of: [updated], timeout: 2)
        withExtendedLifetime(reading) { watch.cancel() }
    }

    func testThePositionsWatchReadsAgainOnAnAccountEventInsteadOfATimer() async {
        let api = AccountStubAPI(account: .init(), balance: .init(available_balance: "90"))
        let (signals, channel) = AsyncStream<PerpsRealtimeSignal>.makeStream()
        let reads = expectation(description: "a read on opening and one on the event")
        reads.expectedFulfillmentCount = 2
        let reading = PerpsTkAccountReading(api: api, liveFeed: PerpsLiveFeed(signals: { signals }), isRealtimeEnabled: { true })
        let watch = reading.watchPositions(
            wallet: makeWallet(),
            pollInterval: 0.5,
            focus: { .portfolio },
            onUpdate: { _ in reads.fulfill() },
            onInterrupted: { XCTFail("the portfolio read should succeed") }
        )

        channel.yield(.subscribed(recovered: true))
        try? await Task.sleep(nanoseconds: 300_000_000)
        channel.yield(.event(.account))

        await fulfillment(of: [reads], timeout: 2)
        withExtendedLifetime(reading) { watch.cancel() }
    }

    func testAnIdleRealtimeWatchReadsOnceTheFocusTurnsToThePortfolioWithoutAnEvent() async {
        let api = AccountStubAPI(account: .init(), balance: .init(available_balance: "90"))
        let (signals, channel) = AsyncStream<PerpsRealtimeSignal>.makeStream()
        let focus = WatchFocusBox()
        let read = expectation(description: "a read once the focus turns to the portfolio")
        read.assertForOverFulfill = false
        let reading = PerpsTkAccountReading(api: api, liveFeed: PerpsLiveFeed(signals: { signals }), isRealtimeEnabled: { true })
        let watch = reading.watchPositions(
            wallet: makeWallet(),
            pollInterval: 0.2,
            focus: { focus.value },
            onUpdate: { _ in read.fulfill() },
            onInterrupted: { XCTFail("the portfolio read should succeed") }
        )

        channel.yield(.subscribed(recovered: true))
        try? await Task.sleep(nanoseconds: 300_000_000)
        focus.value = .portfolio

        await fulfillment(of: [read], timeout: 2)
        withExtendedLifetime(reading) { watch.cancel() }
    }

    func testAnotherPortfolioErrorDoesNotUseTheFallback() async {
        let api = AccountStubAPI(
            account: .init(),
            portfolioError: .badStatus(.init(
                httpStatus: 400,
                code: "invalid_request",
                message: nil,
                retryable: false,
                reason: nil
            ))
        )

        do {
            _ = try await PerpsTkAccountReading(api: api).portfolio(wallet: makeWallet())
            XCTFail("an unrelated refusal must not appear as a portfolio")
        } catch let PerpsAPIError.badStatus(failure) {
            XCTAssertEqual(failure.code, "invalid_request")
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testAnAccountWithoutATradingKeyIsStillReadable() async {
        let reading = PerpsTkAccountReading(api: AccountStubAPI(account: .init(
            account_index: 747_112,
            l1_address: "0x7ECebAF27c989adEF9EA3DD06D316F6F463a5109",
            status: .not_registered,
            has_l2_key: false,
            collateral: "2.000000",
            equity: "2.500000",
            available_balance: "2.000000"
        )))

        guard case let .account(accountIndex, hasTradingKey, _, availableBalance, collateral, equity) = await reading.status(
            wallet: makeWallet()
        ) else {
            return XCTFail("an account the venue knows must resolve to .account")
        }
        XCTAssertEqual(accountIndex, 747_112)
        XCTAssertEqual(hasTradingKey, false)
        XCTAssertEqual(availableBalance, "2.000000")
        XCTAssertEqual(collateral, "2.000000")
        XCTAssertEqual(equity, "2.500000")
    }

    func testABoundWalletAwaitingItsFirstDepositIsNoAccount() async {
        let reading = PerpsTkAccountReading(api: AccountStubAPI(account: .init(
            l1_address: Self.ethAddress.lowercased(),
            status: .not_registered
        )))

        guard case let .noAccount(ethAddress) = await reading.status(wallet: makeWallet()) else {
            return XCTFail("a bound wallet with no account index must resolve to .noAccount")
        }
        XCTAssertEqual(ethAddress, Self.ethAddress.lowercased())
    }

    func testAWalletTheServiceHasNoAddressForIsUnbound() async {
        let reading = PerpsTkAccountReading(api: AccountStubAPI(account: .init(status: .not_registered)))

        guard case .unbound = await reading.status(wallet: makeWallet()) else {
            return XCTFail("an absent l1_address is the only sign that nothing was ever proved")
        }
    }

    func testTheBindProofCommitsToTheDomainWalletAndAddressInThatOrder() throws {
        let walletId = "aiatpf2bzwbz63zdl33ogdknwn7nkhdurfua"
        let l1Address = "0x7ecebaf27c989adef9ea3dd06d316f6f463a5109"
        let message = try PerpsAccountBindSigner.proofMessage(walletId: walletId, l1Address: l1Address)

        let domain = Array("perps.account.bind.v1".utf8)
        var expected = Data([UInt8(domain.count)]) + Data(domain)
        expected += Data([UInt8(walletId.utf8.count)]) + Data(walletId.utf8)
        expected += Data([UInt8(l1Address.utf8.count)]) + Data(l1Address.utf8)

        XCTAssertEqual(message, expected)
        XCTAssertEqual(message.count, 1 + 21 + 1 + 36 + 1 + 42)
        XCTAssertEqual(message.first, 21)
    }

    func testTheBindTypedDataIsLinkWalletUnderThePerpsDomain() throws {
        let json = PerpsRootProofSigner.linkWalletTypedData(walletId: "wallet-id", deadline: 1_755_600_000)
        let parsed = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any]
        )

        XCTAssertEqual(parsed["primaryType"] as? String, "LinkWallet")
        let domain = try XCTUnwrap(parsed["domain"] as? [String: Any])
        XCTAssertEqual(domain["name"] as? String, "TonkeeperPerps")
        XCTAssertEqual(domain["version"] as? String, "1")
        XCTAssertEqual(domain["chainId"] as? Int, 1)
        XCTAssertNil(domain["verifyingContract"])

        let message = try XCTUnwrap(parsed["message"] as? [String: Any])
        XCTAssertEqual(message["walletId"] as? String, "wallet-id")
        XCTAssertEqual(message["deadline"] as? Int64, 1_755_600_000)

        let types = try XCTUnwrap(parsed["types"] as? [String: Any])
        let linkWallet = try XCTUnwrap(types["LinkWallet"] as? [[String: String]])
        XCTAssertEqual(linkWallet.map(\.["name"]), ["walletId", "deadline"])
        XCTAssertEqual(linkWallet.map(\.["type"]), ["string", "uint64"])
        let eip712Domain = try XCTUnwrap(types["EIP712Domain"] as? [[String: String]])
        XCTAssertEqual(eip712Domain.map(\.["name"]), ["name", "version", "chainId"])
    }

    func testTheSendReasonIsWhatAsksForAResign() {
        XCTAssertTrue(
            PerpsAPIError.badStatus(
                PerpsAPIFailure(httpStatus: 400, code: "validation_error", message: nil, retryable: false, reason: "resign_required")
            ).isResignRequired
        )
        XCTAssertFalse(
            PerpsAPIError.badStatus(
                PerpsAPIFailure(httpStatus: 400, code: "validation_error", message: nil, retryable: false, reason: "order_gone")
            ).isResignRequired
        )
        XCTAssertFalse(PerpsAPIError.conflict.isResignRequired)
    }

    func testRegistrationConfirmationBacksOffAndThenHoldsItsCeiling() {
        let delays = (0 ..< 6).map { PerpsAccountService.registrationConfirmationDelayNanoseconds(attempt: $0) }
        XCTAssertEqual(delays, [500_000_000, 1_000_000_000, 2_000_000_000, 4_000_000_000, 4_000_000_000, 4_000_000_000])

        let window = (0 ..< PerpsAccountService.registrationConfirmationAttempts)
            .reduce(UInt64(0)) { $0 + PerpsAccountService.registrationConfirmationDelayNanoseconds(attempt: $1) }
        XCTAssertGreaterThan(window, 30_000_000_000)
    }
}

private extension PerpsAccountStatusMappingTests {
    static let ethAddress = "0x7ECebAF27c989adEF9EA3DD06D316F6F463a5109"

    func makeWallet() -> Wallet {
        let publicKey = TonSwift.PublicKey(data: Data(repeating: 1, count: 32))
        return Wallet(
            id: "perps-wallet",
            identity: WalletIdentity(network: .mainnet, kind: .Regular(publicKey, .v4R2)),
            metaData: WalletMetaData(label: "Perps", tintColor: .defaultColor, icon: .icon(.wallet)),
            setupSettings: WalletSetupSettings(isSetupFinished: true),
            batterySettings: BatterySettings(),
            multichain: .multichain(MultichainWalletState(
                walletId: "perps-multichain-wallet",
                addresses: [MultichainWalletAddress(chain: .eth, address: Self.ethAddress)],
                syncState: .synced
            ))
        )
    }
}

final class AccountStubAPI: PerpsAPI, Sendable {
    struct Unsupported: Error {}

    private let account: Components.Schemas.Account
    private let balance: Components.Schemas.Balance?
    private let portfolioError: PerpsAPIError?
    private let positions: [Components.Schemas.OpenPosition]
    private let openOrders: [Components.Schemas.PortfolioOrder]
    private let orderError: PerpsAPIError?
    private let orderDetail: Components.Schemas.OrderDetail?
    private let onAccount: @Sendable () async throws -> Void
    /// `nil` refuses every issue.
    private let onIssueReadOnlyToken: (@Sendable () async -> Void)?
    private let onAccountTier: (@Sendable () async throws -> Components.Schemas.AccountTier)?
    private let onChangeAccountTier: (@Sendable (String) async -> Void)?
    private let onLighterAuth: (@Sendable (String) async -> Void)?
    private let onBindAccount: (@Sendable (Components.Schemas.BindAccountRequest) async throws -> Components.Schemas.Account)?
    private let integrator: Components.Schemas.Integrator
    private let nonce: Int64?
    private let onNextNonce: (@Sendable () async throws -> Int64)?
    private let tradingScreen: Components.Schemas.TradingScreen?
    private let orderBook: Components.Schemas.TruncatedOrderBook?
    private let openPosition: Components.Schemas.OpenPositionDetail?
    private let onPositionState: (@Sendable (Int64?) async throws -> Components.Schemas.PositionState)?
    private let onSendTransactions: (@Sendable (_ walletId: String, _ transactions: [Components.Schemas.SignedTransaction]) async throws -> Components.Schemas.SendTransactionsResponse)?
    private let onPortfolio: (@Sendable () -> Void)?
    private let onQuoteWithdraw: (@Sendable (Components.Schemas.WithdrawQuoteRequest) async throws -> Components.Schemas.WithdrawQuote)?

    init(
        account: Components.Schemas.Account,
        balance: Components.Schemas.Balance? = nil,
        portfolioError: PerpsAPIError? = nil,
        positions: [Components.Schemas.OpenPosition] = [],
        openOrders: [Components.Schemas.PortfolioOrder] = [],
        orderError: PerpsAPIError? = nil,
        orderDetail: Components.Schemas.OrderDetail? = nil,
        onIssueReadOnlyToken: (@Sendable () async -> Void)? = nil,
        onAccountTier: (@Sendable () async throws -> Components.Schemas.AccountTier)? = nil,
        onChangeAccountTier: (@Sendable (String) async -> Void)? = nil,
        onLighterAuth: (@Sendable (String) async -> Void)? = nil,
        onBindAccount: (@Sendable (Components.Schemas.BindAccountRequest) async throws -> Components.Schemas.Account)? = nil,
        integrator: Components.Schemas.Integrator = .none,
        nonce: Int64? = nil,
        onNextNonce: (@Sendable () async throws -> Int64)? = nil,
        tradingScreen: Components.Schemas.TradingScreen? = nil,
        orderBook: Components.Schemas.TruncatedOrderBook? = nil,
        onPositionState: (@Sendable (Int64?) async throws -> Components.Schemas.PositionState)? = nil,
        openPosition: Components.Schemas.OpenPositionDetail? = nil,
        onSendTransactions: (@Sendable (_ walletId: String, _ transactions: [Components.Schemas.SignedTransaction]) async throws -> Components.Schemas.SendTransactionsResponse)? = nil,
        onPortfolio: (@Sendable () -> Void)? = nil,
        onQuoteWithdraw: (@Sendable (Components.Schemas.WithdrawQuoteRequest) async throws -> Components.Schemas.WithdrawQuote)? = nil,
        onAccount: @escaping @Sendable () async throws -> Void = {}
    ) {
        self.onPortfolio = onPortfolio
        self.onQuoteWithdraw = onQuoteWithdraw
        self.account = account
        self.balance = balance
        self.portfolioError = portfolioError
        self.positions = positions
        self.openOrders = openOrders
        self.orderError = orderError
        self.orderDetail = orderDetail
        self.onAccount = onAccount
        self.onIssueReadOnlyToken = onIssueReadOnlyToken
        self.onAccountTier = onAccountTier
        self.onChangeAccountTier = onChangeAccountTier
        self.onLighterAuth = onLighterAuth
        self.onBindAccount = onBindAccount
        self.integrator = integrator
        self.nonce = nonce
        self.onNextNonce = onNextNonce
        self.tradingScreen = tradingScreen
        self.orderBook = orderBook
        self.onPositionState = onPositionState
        self.openPosition = openPosition
        self.onSendTransactions = onSendTransactions
    }

    func account(walletId _: String) async throws -> Components.Schemas.Account {
        try await onAccount()
        return account
    }

    func integrator(walletId _: String) async throws -> Components.Schemas.Integrator {
        integrator
    }

    func bindAccount(
        walletId _: String,
        request: Components.Schemas.BindAccountRequest
    ) async throws -> Components.Schemas.Account {
        guard let onBindAccount else { throw Unsupported() }
        return try await onBindAccount(request)
    }

    func tradingScreen(walletId _: String, marketId _: Int64) async throws -> Components.Schemas.TradingScreen {
        guard let tradingScreen else { throw Unsupported() }
        return tradingScreen
    }

    func truncatedOrderBook(
        walletId _: String,
        marketId _: Int64,
        side _: Operations.getTruncatedOrderBook.Input.Query.sidePayload,
        feeRate _: String,
        notional _: String
    ) async throws -> Components.Schemas.TruncatedOrderBook {
        guard let orderBook else { throw Unsupported() }
        return orderBook
    }

    func issueReadOnlyToken(
        walletId _: String,
        lighterAuth: String
    ) async throws -> Components.Schemas.IssuedRoToken {
        await onLighterAuth?(lighterAuth)
        guard let onIssueReadOnlyToken else { throw PerpsAPIError.unauthorized }
        await onIssueReadOnlyToken()
        return .init(token: "ro", token_id: 1, account_index: 1, issued_at: Date(), expires_at: Date())
    }

    func nextNonce(walletId _: String, apiKeyIndex _: Int) async throws -> Components.Schemas.NextNonce {
        if let onNextNonce {
            return try await .init(account_index: 0, nonce: onNextNonce())
        }
        guard let nonce else { throw Unsupported() }
        return .init(account_index: 0, nonce: nonce)
    }

    func sendTransactions(
        walletId: String,
        operationId _: String?,
        transactions: [Components.Schemas.SignedTransaction]
    ) async throws -> Components.Schemas.SendTransactionsResponse {
        guard let onSendTransactions else { throw Unsupported() }
        return try await onSendTransactions(walletId, transactions)
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

    func quoteWithdraw(walletId _: String, request: Components.Schemas.WithdrawQuoteRequest) async throws -> Components.Schemas.WithdrawQuote {
        guard let onQuoteWithdraw else { throw Unsupported() }
        return try await onQuoteWithdraw(request)
    }

    func getFundingStatus(
        walletId _: String,
        executionId _: String
    ) async throws -> Components.Schemas.FundingStatus {
        throw Unsupported()
    }

    func portfolio(walletId _: String) async throws -> Components.Schemas.Portfolio {
        onPortfolio?()
        if let portfolioError { throw portfolioError }
        return .init(balance: balance, positions: positions, open_orders: openOrders)
    }

    func getOrder(walletId _: String, id _: String) async throws -> Components.Schemas.OrderDetail {
        if let orderError { throw orderError }
        guard let orderDetail else { throw Unsupported() }
        return orderDetail
    }

    func recordClientMetrics(walletId _: String, metrics _: [Components.Schemas.ClientMetric]) async throws {}

    func listOpenPositions(walletId _: String) async throws -> Components.Schemas.OpenPositionsPage {
        .init(positions: positions)
    }

    func getOpenPosition(walletId _: String, id _: String) async throws -> Components.Schemas.OpenPositionDetail {
        guard let openPosition else { throw Unsupported() }
        return openPosition
    }

    func positionState(
        walletId _: String,
        id _: String,
        clientOrderIndex: Int64?
    ) async throws -> Components.Schemas.PositionState {
        guard let onPositionState else { throw Unsupported() }
        return try await onPositionState(clientOrderIndex)
    }

    func accountTier(walletId _: String) async throws -> Components.Schemas.AccountTier {
        guard let onAccountTier else { throw Unsupported() }
        return try await onAccountTier()
    }

    func changeAccountTier(walletId _: String, lighterAuth: String, newTier: String) async throws {
        await onLighterAuth?(lighterAuth)
        guard let onChangeAccountTier else { throw Unsupported() }
        await onChangeAccountTier(newTier)
    }

    func withdrawals(walletId _: String, cursor _: String?) async throws -> Components.Schemas.ActivityPage {
        throw Unsupported()
    }
}
