import Foundation
@testable import KeeperCore
import TKPerpsAPI
import TonSwift
import XCTest

final class PerpsAccountStatusMappingTests: XCTestCase {
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

    func testPositionsWatchKeepsPollingWhenPortfolioAndOrdersNeedAToken() async {
        let api = AccountStubAPI(
            account: .init(),
            portfolioError: .badStatus(.init(
                httpStatus: 400,
                code: "readonly_token_unavailable",
                message: nil,
                retryable: false,
                reason: nil
            )),
            positions: [.init(market_index: 1, symbol: "BTC", size: "0.1")],
            orderError: .badStatus(.init(
                httpStatus: 400,
                code: "readonly_token_unavailable",
                message: nil,
                retryable: false,
                reason: nil
            ))
        )
        let updated = expectation(description: "positions read without a token")
        updated.expectedFulfillmentCount = 2
        updated.assertForOverFulfill = false
        let reading = PerpsTkAccountReading(api: api)
        let watch = reading.watchPositions(
            wallet: makeWallet(),
            pollInterval: 0.5,
            focus: { .positionsAndOrders(["order"]) },
            onUpdate: { tick in
                guard case let .positions(positions, openOrders) = tick,
                      positions.map(\.marketId) == [1],
                      openOrders == nil
                else { return }
                updated.fulfill()
            },
            onInterrupted: { XCTFail("the positions read should use the fallback") }
        )

        await fulfillment(of: [updated], timeout: 2)
        withExtendedLifetime(reading) { watch.cancel() }
    }

    func testThePositionsPollCarriesThePortfolioOrders() async {
        let api = AccountStubAPI(
            account: .init(),
            openOrders: [.init(
                order_index: 21,
                market_index: 1,
                symbol: "BTC",
                side: .long,
                _type: .limit,
                category: .open,
                base_size: "0.0003",
                price: "80000"
            )]
        )
        let updated = expectation(description: "orders read with the positions")
        updated.assertForOverFulfill = false
        let reading = PerpsTkAccountReading(api: api)
        let watch = reading.watchPositions(
            wallet: makeWallet(),
            pollInterval: 0.5,
            focus: { .positions },
            onUpdate: { tick in
                guard case let .positions(_, openOrders) = tick, openOrders?.map(\.order.orderIndex) == [21] else { return }
                updated.fulfill()
            },
            onInterrupted: { XCTFail("the portfolio read should succeed") }
        )

        await fulfillment(of: [updated], timeout: 2)
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
        let json = PerpsAccountBindSigner.typedData(walletId: "wallet-id", deadline: 1_755_600_000)
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
    private let openOrders: [Components.Schemas.Order]
    private let orderError: PerpsAPIError?
    private let onAccount: @Sendable () async throws -> Void
    /// `nil` refuses every issue.
    private let onIssueReadOnlyToken: (@Sendable () async -> Void)?
    private let onAccountTier: (@Sendable () async throws -> Components.Schemas.AccountTier)?
    private let onChangeAccountTier: (@Sendable (String) async -> Void)?
    private let integrator: Components.Schemas.Integrator
    private let nonce: Int64?
    private let tradingScreen: Components.Schemas.TradingScreen?
    private let orderBook: Components.Schemas.TruncatedOrderBook?
    private let onSendTransactions: (@Sendable ([Components.Schemas.SignedTransaction]) async throws -> Components.Schemas.SendTransactionsResponse)?

    init(
        account: Components.Schemas.Account,
        balance: Components.Schemas.Balance? = nil,
        portfolioError: PerpsAPIError? = nil,
        positions: [Components.Schemas.OpenPosition] = [],
        openOrders: [Components.Schemas.Order] = [],
        orderError: PerpsAPIError? = nil,
        onIssueReadOnlyToken: (@Sendable () async -> Void)? = nil,
        onAccountTier: (@Sendable () async throws -> Components.Schemas.AccountTier)? = nil,
        onChangeAccountTier: (@Sendable (String) async -> Void)? = nil,
        integrator: Components.Schemas.Integrator = .none,
        nonce: Int64? = nil,
        tradingScreen: Components.Schemas.TradingScreen? = nil,
        orderBook: Components.Schemas.TruncatedOrderBook? = nil,
        onSendTransactions: (@Sendable ([Components.Schemas.SignedTransaction]) async throws -> Components.Schemas.SendTransactionsResponse)? = nil,
        onAccount: @escaping @Sendable () async throws -> Void = {}
    ) {
        self.account = account
        self.balance = balance
        self.portfolioError = portfolioError
        self.positions = positions
        self.openOrders = openOrders
        self.orderError = orderError
        self.onAccount = onAccount
        self.onIssueReadOnlyToken = onIssueReadOnlyToken
        self.onAccountTier = onAccountTier
        self.onChangeAccountTier = onChangeAccountTier
        self.integrator = integrator
        self.nonce = nonce
        self.tradingScreen = tradingScreen
        self.orderBook = orderBook
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
        request _: Components.Schemas.BindAccountRequest
    ) async throws -> Components.Schemas.Account {
        throw Unsupported()
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
        lighterAuth _: String
    ) async throws -> Components.Schemas.IssuedRoToken {
        guard let onIssueReadOnlyToken else { throw PerpsAPIError.unauthorized }
        await onIssueReadOnlyToken()
        return .init(token: "ro", token_id: 1, account_index: 1, issued_at: Date(), expires_at: Date())
    }

    func nextNonce(walletId _: String, apiKeyIndex _: Int) async throws -> Components.Schemas.NextNonce {
        guard let nonce else { throw Unsupported() }
        return .init(account_index: 0, nonce: nonce)
    }

    func sendTransactions(
        walletId _: String,
        transactions: [Components.Schemas.SignedTransaction]
    ) async throws -> Components.Schemas.SendTransactionsResponse {
        guard let onSendTransactions else { throw Unsupported() }
        return try await onSendTransactions(transactions)
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

    func portfolio(walletId _: String) async throws -> Components.Schemas.Portfolio {
        if let portfolioError { throw portfolioError }
        return .init(balance: balance, positions: positions, open_orders: openOrders)
    }

    func getOrder(walletId _: String, id _: String) async throws -> Components.Schemas.OrderDetail {
        if let orderError { throw orderError }
        throw Unsupported()
    }

    func listOpenPositions(walletId _: String) async throws -> Components.Schemas.OpenPositionsPage {
        .init(positions: positions)
    }

    func getOpenPosition(walletId _: String, id _: String) async throws -> Components.Schemas.OpenPositionDetail {
        throw Unsupported()
    }

    func positionState(
        walletId _: String,
        id _: String,
        clientOrderIndex _: Int64?
    ) async throws -> Components.Schemas.PositionState {
        throw Unsupported()
    }

    func accountTier(walletId _: String) async throws -> Components.Schemas.AccountTier {
        guard let onAccountTier else { throw Unsupported() }
        return try await onAccountTier()
    }

    func changeAccountTier(walletId _: String, lighterAuth _: String, newTier: String) async throws {
        guard let onChangeAccountTier else { throw Unsupported() }
        await onChangeAccountTier(newTier)
    }

    func withdrawals(walletId _: String, cursor _: String?) async throws -> Components.Schemas.ActivityPage {
        throw Unsupported()
    }
}
