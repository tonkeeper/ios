import Foundation
@testable import KeeperCore
import TKPerpsAPI
import XCTest

final class PerpsDepositRegistrarTests: XCTestCase {
    private var directoryURL: URL!

    override func setUpWithError() throws {
        directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("PerpsDepositRegistrarTests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directoryURL)
        directoryURL = nil
    }

    func testRegistrationSendsTheSignedBodyVerbatim() async throws {
        let api = FundingStubAPI(openDeposit: .success(.init(deposit_id: "dep-1", status: .pending)))
        let (registrar, operation) = try await makeRegistrar(api: api)

        _ = try await registrar.register(operation: operation)

        let requests = await api.openDepositRequests
        let request = try XCTUnwrap(requests.first)
        XCTAssertEqual(request.operation_id, "op-1")
        XCTAssertEqual(request.asset_id, "eth/mainnet/erc20/0xa0b8")
        XCTAssertEqual(request.amount, "25")
        XCTAssertEqual(request.l1_tx_hash, "0x" + String(repeating: "a", count: 64))
        XCTAssertNil(request.execution_id)
    }

    func testUnchangedPendingResponseKeepsTheJournalRevision() async throws {
        let response = Components.Schemas.Deposit(deposit_id: "dep-1", status: .pending)
        let api = FundingStubAPI(openDeposit: .success(response), getDeposit: .success(response))
        let (registrar, operation) = try await makeRegistrar(api: api)
        let registered = try await registrar.register(operation: operation)
        let refreshed = try await registrar.refresh(operation: registered)
        XCTAssertEqual(refreshed, registered)
    }

    func testTheRecordedDepositIdIsTheOneTheBackendAnswered() async throws {
        let api = FundingStubAPI(openDeposit: .success(.init(deposit_id: "dep-earlier", status: .pending)))
        let (registrar, operation) = try await makeRegistrar(api: api)

        let registered = try await registrar.register(operation: operation)

        XCTAssertEqual(registered.deposit?.depositId, "dep-earlier")
        XCTAssertEqual(registered.deposit?.stage, .registeredPending)
    }

    /// The id can be recorded by the backend and still never reach the journal — a pass
    /// cancelled between the two, a revision that moved under the write. Nothing local holds
    /// it then, and the only way back to it is reposting the same body: operation_id is what
    /// makes this call idempotent, so the backend answers with the deposit it already has
    /// rather than recording the payment a second time.
    func testALostWriteIsRecoveredByRepostingTheSameBody() async throws {
        let recorded = expectation(description: "the backend recorded the deposit")
        let gate = RecoveryGate()
        let api = FundingStubAPI(openDeposit: .success(.init(deposit_id: "dep-1", status: .pending))) { attempt in
            guard attempt == 1 else { return }
            recorded.fulfill()
            await gate.wait()
        }
        let operation = try await save(makeOperation())
        let store = journal()
        let interrupted = Task { [api] in
            try await PerpsDepositRegistrar(api: api, journal: store).register(operation: operation)
        }
        await fulfillment(of: [recorded], timeout: 2)
        interrupted.cancel()
        await gate.open()
        do {
            _ = try await interrupted.value
            XCTFail("a cancelled pass must not be reported as a recorded deposit")
        } catch is CancellationError {}
        let lost = try await journal().funding(operationId: "op-1")
        XCTAssertEqual(lost, operation)

        let registered = try await PerpsDepositRegistrar(api: api, journal: journal())
            .register(operation: XCTUnwrap(lost))

        XCTAssertEqual(registered.deposit?.depositId, "dep-1")
        XCTAssertEqual(registered.deposit?.stage, .registeredPending)
        let requests = await api.openDepositRequests
        XCTAssertEqual(requests.count, 2)
        XCTAssertEqual(requests.first, requests.last)
    }

    func testAnInvalidRegistrationResponseKeepsTheOriginalRequestRetryable() async throws {
        let responses: [Components.Schemas.Deposit] = [
            .init(status: .pending),
            .init(deposit_id: " \n", status: .pending),
            .init(deposit_id: "dep-1", status: .credited, l1_tx_hash: "0x" + String(repeating: "d", count: 64)),
        ]
        for response in responses {
            let api = FundingStubAPI(openDeposit: .success(response))
            let (registrar, operation) = try await makeRegistrar(api: api)

            do {
                _ = try await registrar.register(operation: operation)
                XCTFail("an invalid response must not advance the operation")
            } catch is PerpsDepositRegistrationError {}

            let stored = try await journal().funding(operationId: operation.operationId)
            XCTAssertEqual(stored, operation)
        }
    }

    func testPollingAnotherDepositsResponseCannotCreditThisOperation() async throws {
        let responses: [Components.Schemas.Deposit] = [
            .init(deposit_id: "dep-other", status: .credited),
            .init(deposit_id: "dep-1", status: .credited, l1_tx_hash: "0x" + String(repeating: "d", count: 64)),
        ]
        let setupAPI = FundingStubAPI(openDeposit: .success(.init(deposit_id: "dep-1", status: .pending)))
        let (registrar, operation) = try await makeRegistrar(api: setupAPI)
        let registered = try await registrar.register(operation: operation)
        for response in responses {
            let reader = PerpsDepositRegistrar(api: FundingStubAPI(getDeposit: .success(response)), journal: journal())
            do {
                _ = try await reader.refresh(operation: registered)
                XCTFail("a response for another deposit must be refused")
            } catch {
                XCTAssertEqual(error as? PerpsDepositRegistrationError, .mismatchedDeposit("op-1"))
            }
            let stored = try await journal().funding(operationId: operation.operationId)
            XCTAssertEqual(stored, registered)
        }
    }

    func testAClosedBackendRecordIsNotPolledAgain() async throws {
        let api = FundingStubAPI(openDeposit: .success(.init(deposit_id: "dep-1", status: .pending)))
        let (registrar, operation) = try await makeRegistrar(api: api)
        var current = try await registrar.register(operation: operation)
        for stage in [PerpsDepositStage.credited, .unconfirmed] {
            current = try await journal().updateFunding(operationId: "op-1", expectedRevision: current.revision) {
                var deposit = try XCTUnwrap($0.deposit)
                deposit.stage = stage
                $0.details = .deposit(deposit)
            }
            do {
                _ = try await registrar.refresh(operation: current)
                XCTFail("the backend does not revise closed records")
            } catch {
                XCTAssertEqual(error as? PerpsDepositRegistrationError, .unexpectedStage("op-1"))
            }
        }
        let requests = await api.getDepositRequests
        XCTAssertEqual(requests, 0)
    }

    func testAnOutageLeavesTheRegistrationForARetry() async throws {
        let api = FundingStubAPI(openDeposit: .failure(.badStatus(.undecoded(503, message: "upstream unavailable"))))
        let (registrar, operation) = try await makeRegistrar(api: api)

        do {
            _ = try await registrar.register(operation: operation)
            XCTFail("an outage must not resolve the registration")
        } catch {}

        let stored = try await journal().funding(operationId: "op-1")
        XCTAssertEqual(stored?.deposit?.stage, .registrationPending)
        XCTAssertEqual(stored?.revision, operation.revision)
    }

    func testRegisteringTwiceIsRefusedOnceTheStageMovedOn() async throws {
        let api = FundingStubAPI(openDeposit: .success(.init(deposit_id: "dep-1", status: .pending)))
        let (registrar, operation) = try await makeRegistrar(api: api)
        let registered = try await registrar.register(operation: operation)

        do {
            _ = try await registrar.register(operation: registered)
            XCTFail("a recorded deposit must not be posted again")
        } catch {
            XCTAssertEqual(
                error as? PerpsDepositRegistrationError,
                .unexpectedStage("op-1")
            )
        }
        let requests = await api.openDepositRequests.count
        XCTAssertEqual(requests, 1)
    }

    func testCreditWithoutAnAmountDoesNotInventOne() async throws {
        let api = FundingStubAPI(
            openDeposit: .success(.init(deposit_id: "dep-1", status: .pending)),
            getDeposit: .success(.init(deposit_id: "dep-1", status: .credited, account_index: 736_568))
        )
        let (registrar, operation) = try await makeRegistrar(api: api)
        let registered = try await registrar.register(operation: operation)

        let credited = try await registrar.refresh(operation: registered)

        XCTAssertEqual(credited.deposit?.stage, .credited)
        XCTAssertNil(credited.deposit?.creditedAmount)
        XCTAssertEqual(credited.deposit?.accountIndex, 736_568)
    }

    func testUnfundedIsRecordedAsUnconfirmed() async throws {
        let registered = try await makeRegistered(
            getDeposit: .success(.init(deposit_id: "dep-1", status: .unfunded))
        )

        XCTAssertEqual(registered.deposit?.stage, .unconfirmed)
        XCTAssertFalse(registered.isOutcome)
        XCTAssertTrue(registered.isUnresolved)
    }

    func testTerminalStatusesKeepTheirMeaning() {
        XCTAssertEqual(PerpsDepositRecord(.init(status: .failed)).status, .failed)
        XCTAssertEqual(PerpsDepositRecord(.init(status: .refunded)).status, .refunded)
        XCTAssertEqual(PerpsDepositRecord(.init(status: .expired)).status, .expired)
    }

    func testAStatusThisBuildDoesNotKnowIsNotAnOutcome() async throws {
        let registered = try await makeRegistered(
            getDeposit: .success(.init(deposit_id: "dep-1", status: nil, account_index: 736_568))
        )

        XCTAssertEqual(registered.deposit?.stage, .registeredPending)
        XCTAssertEqual(registered.deposit?.accountIndex, 736_568)
        XCTAssertTrue(registered.isUnresolved)
    }

    func testAnAccountIndexBeforeTheCreditKeepsTheDepositPending() async throws {
        let registered = try await makeRegistered(
            getDeposit: .success(.init(deposit_id: "dep-1", status: .pending, account_index: 736_568))
        )

        XCTAssertEqual(registered.deposit?.stage, .registeredPending)
        XCTAssertEqual(registered.deposit?.accountIndex, 736_568)
    }

    func testADepositWithoutARecordedIdCannotBePolled() async throws {
        let api = FundingStubAPI()
        let (registrar, operation) = try await makeRegistrar(api: api)

        do {
            _ = try await registrar.refresh(operation: operation)
            XCTFail("polling needs the id the backend answered")
        } catch {
            XCTAssertEqual(error as? PerpsDepositRegistrationError, .missingDepositId("op-1"))
        }
    }

    func testRegistrationNeedsTheSignedBody() async throws {
        let api = FundingStubAPI()
        let registrar = PerpsDepositRegistrar(api: api, journal: journal())
        let operation = try await save(makeOperation(registration: nil))

        do {
            _ = try await registrar.register(operation: operation)
            XCTFail("an unsigned registration must not be posted")
        } catch {
            XCTAssertEqual(error as? PerpsDepositRegistrationError, .missingRegistration("op-1"))
        }
    }
}

private extension PerpsDepositRegistrarTests {
    func journal() -> PerpsPendingJournal {
        PerpsPendingJournal(walletId: "wallet", environment: "test", directoryURL: directoryURL)
    }

    func makeRegistrar(
        api: FundingStubAPI
    ) async throws -> (PerpsDepositRegistrar, PerpsPendingFundingOperation) {
        let operation = try await save(makeOperation())
        return (PerpsDepositRegistrar(api: api, journal: journal()), operation)
    }

    func makeRegistered(
        getDeposit: Result<Components.Schemas.Deposit, PerpsAPIError>
    ) async throws -> PerpsPendingFundingOperation {
        let api = FundingStubAPI(
            openDeposit: .success(.init(deposit_id: "dep-1", status: .pending)),
            getDeposit: getDeposit
        )
        let (registrar, operation) = try await makeRegistrar(api: api)
        let registered = try await registrar.register(operation: operation)
        return try await registrar.refresh(operation: registered)
    }

    func save(_ operation: PerpsPendingFundingOperation) async throws -> PerpsPendingFundingOperation {
        try await journal().saveFundingIfAbsent(operation).operation
    }

    func makeOperation(registration: PerpsDepositRegistration? = .stub) -> PerpsPendingFundingOperation {
        PerpsPendingFundingOperation(
            operationId: "op-1",
            walletId: "wallet",
            walletIdentity: "identity",
            environment: "test",
            details: .deposit(PerpsPendingDeposit(
                stage: .registrationPending,
                route: .directGateway,
                beneficiary: "0xabc",
                sourceAsset: .usdcEthereum,
                sourceAmountUnits: "25000000",
                targetAsset: .usdcEthereum,
                minimumTargetAmountUnits: "25000000",
                registration: registration
            ))
        )
    }
}

private extension PerpsFundingAsset {
    static let usdcEthereum = PerpsFundingAsset(
        assetId: "eth/mainnet/erc20/0xa0b8",
        symbol: "USDC",
        decimals: 6
    )
}

private extension PerpsDepositRegistration {
    static let stub = PerpsDepositRegistration(
        operationId: "op-1",
        assetId: "eth/mainnet/erc20/0xa0b8",
        amount: "25",
        l1TxHash: "0x" + String(repeating: "a", count: 64),
        executionId: nil
    )
}

actor FundingStubAPI: PerpsAPI {
    struct Unsupported: Error {}

    private(set) var openDepositRequests = [Components.Schemas.OpenDepositRequest]()
    private(set) var getDepositRequests = 0
    private(set) var quoteDepositRequests = [Components.Schemas.DepositQuoteRequest]()
    private var openDepositResult: Result<Components.Schemas.Deposit, PerpsAPIError>?
    private let getDepositResult: Result<Components.Schemas.Deposit, PerpsAPIError>?
    private let quoteDepositResult: Result<Components.Schemas.DepositQuote, PerpsAPIError>?
    private let quoteDepositHandler: (@Sendable (Components.Schemas.DepositQuoteRequest) throws -> Components.Schemas.DepositQuote)?
    private let fundingStatusResult: Result<Components.Schemas.FundingStatus, PerpsAPIError>?
    private let nextNonceResult: Result<Components.Schemas.NextNonce, PerpsAPIError>?
    private(set) var fundingStatusRequests = [String]()
    private let withdrawalsResult: Result<Components.Schemas.ActivityPage, PerpsAPIError>?
    private let withdrawalsHandler: (@Sendable (String?) throws -> Components.Schemas.ActivityPage)?
    private(set) var withdrawalsRequests = 0
    private(set) var nextNonceRequests = 0
    private(set) var sendTransactionsRequests = 0
    private let onOpen: @Sendable (Int) async -> Void
    private var accountResult: Result<Components.Schemas.Account, PerpsAPIError> = .success(.init())

    init(
        openDeposit: Result<Components.Schemas.Deposit, PerpsAPIError>? = nil,
        getDeposit: Result<Components.Schemas.Deposit, PerpsAPIError>? = nil,
        quoteDeposit: Result<Components.Schemas.DepositQuote, PerpsAPIError>? = nil,
        quoteDepositHandler: (@Sendable (Components.Schemas.DepositQuoteRequest) throws -> Components.Schemas.DepositQuote)? = nil,
        fundingStatus: Result<Components.Schemas.FundingStatus, PerpsAPIError>? = nil,
        nextNonce: Result<Components.Schemas.NextNonce, PerpsAPIError>? = nil,
        withdrawals: Result<Components.Schemas.ActivityPage, PerpsAPIError>? = nil,
        withdrawalsHandler: (@Sendable (String?) throws -> Components.Schemas.ActivityPage)? = nil,
        onOpen: @escaping @Sendable (Int) async -> Void = { _ in }
    ) {
        openDepositResult = openDeposit
        getDepositResult = getDeposit
        quoteDepositResult = quoteDeposit
        self.quoteDepositHandler = quoteDepositHandler
        fundingStatusResult = fundingStatus
        nextNonceResult = nextNonce
        withdrawalsResult = withdrawals
        self.withdrawalsHandler = withdrawalsHandler
        self.onOpen = onOpen
    }

    func setOpenDepositResult(_ result: Result<Components.Schemas.Deposit, PerpsAPIError>) {
        openDepositResult = result
    }

    func setAccountResult(_ result: Result<Components.Schemas.Account, PerpsAPIError>) {
        accountResult = result
    }

    func openDeposit(
        walletId _: String,
        request: Components.Schemas.OpenDepositRequest
    ) async throws -> Components.Schemas.Deposit {
        openDepositRequests.append(request)
        await onOpen(openDepositRequests.count)
        guard let openDepositResult else { throw Unsupported() }
        return try openDepositResult.get()
    }

    func getDeposit(walletId _: String, depositId _: String) async throws -> Components.Schemas.Deposit {
        getDepositRequests += 1
        guard let getDepositResult else { throw Unsupported() }
        return try getDepositResult.get()
    }

    func quoteDeposit(
        walletId _: String,
        request: Components.Schemas.DepositQuoteRequest
    ) async throws -> Components.Schemas.DepositQuote {
        quoteDepositRequests.append(request)
        if let quoteDepositHandler { return try quoteDepositHandler(request) }
        guard let quoteDepositResult else { throw Unsupported() }
        return try quoteDepositResult.get()
    }

    func quoteWithdraw(walletId _: String, request _: Components.Schemas.WithdrawQuoteRequest) async throws -> Components.Schemas.WithdrawQuote {
        throw Unsupported()
    }

    func getFundingStatus(
        walletId _: String,
        executionId: String
    ) async throws -> Components.Schemas.FundingStatus {
        fundingStatusRequests.append(executionId)
        guard let fundingStatusResult else { throw Unsupported() }
        return try fundingStatusResult.get()
    }

    func account(walletId _: String) async throws -> Components.Schemas.Account {
        try accountResult.get()
    }

    func integrator(walletId _: String) async throws -> Components.Schemas.Integrator {
        .none
    }

    func bindAccount(
        walletId _: String,
        request _: Components.Schemas.BindAccountRequest
    ) async throws -> Components.Schemas.Account {
        throw Unsupported()
    }

    func tradingScreen(walletId _: String, marketId _: Int64) async throws -> Components.Schemas.TradingScreen {
        throw Unsupported()
    }

    func truncatedOrderBook(
        walletId _: String,
        marketId _: Int64,
        side _: Operations.getTruncatedOrderBook.Input.Query.sidePayload,
        feeRate _: String,
        notional _: String
    ) async throws -> Components.Schemas.TruncatedOrderBook {
        throw Unsupported()
    }

    func nextNonce(walletId _: String, apiKeyIndex _: Int) async throws -> Components.Schemas.NextNonce {
        nextNonceRequests += 1
        guard let nextNonceResult else { throw Unsupported() }
        return try nextNonceResult.get()
    }

    func issueReadOnlyToken(
        walletId _: String,
        lighterAuth _: String
    ) async throws -> Components.Schemas.IssuedRoToken {
        throw Unsupported()
    }

    func sendTransactions(
        walletId _: String,
        transactions _: [Components.Schemas.SignedTransaction]
    ) async throws -> Components.Schemas.SendTransactionsResponse {
        sendTransactionsRequests += 1
        throw Unsupported()
    }

    func portfolio(walletId _: String) async throws -> Components.Schemas.Portfolio {
        throw Unsupported()
    }

    func listOpenPositions(walletId _: String) async throws -> Components.Schemas.OpenPositionsPage {
        throw Unsupported()
    }

    func getOrder(walletId _: String, id _: String) async throws -> Components.Schemas.OrderDetail {
        throw Unsupported()
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
        throw Unsupported()
    }

    func changeAccountTier(walletId _: String, lighterAuth _: String, newTier _: String) async throws {
        throw Unsupported()
    }

    func withdrawals(walletId _: String, cursor: String?) async throws -> Components.Schemas.ActivityPage {
        withdrawalsRequests += 1
        if let withdrawalsHandler { return try withdrawalsHandler(cursor) }
        guard let withdrawalsResult else { throw Unsupported() }
        return try withdrawalsResult.get()
    }
}
