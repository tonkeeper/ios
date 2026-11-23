import ChainKit
import Foundation
@testable import KeeperCore
@testable import KeeperCoreComponents
import KeeperCoreSensitive
import PerpsModels
import TKKeychain
import TKPerpsAPI
import TonSwift
import XCTest

final class PerpsIntegratorApprovalTests: XCTestCase {
    private let session = PerpsAccountSession(accountIndex: 748_924, apiKeyIndex: 3)

    func testAutoCloseReloadAfterReconciliationDoesNotJoinAnEarlierScreen() async throws {
        let wallet = makeWallet(id: UUID().uuidString)
        let decided = expectation(description: "both callers have selected their screen read")
        decided.expectedFulfillmentCount = 2
        let reads = PerpsTradingScreenReads(now: {
            decided.fulfill()
            return Date()
        })
        let started = expectation(description: "screen before cancelling TP is in flight")
        let (releases, release) = AsyncStream<Void>.makeStream()
        defer { release.finish() }
        let earlier = Task {
            try await reads.value(for: "\(wallet.id)/1") {
                started.fulfill()
                for await _ in releases {
                    break
                }
                return .init(open_orders: [.init(
                    order_index: 7, side: .short, _type: .limit, status: .open,
                    category: .take_profit, trigger_price: "72000"
                )], flags: .init(cancel_enabled: true))
            }
        }
        await fulfillment(of: [started], timeout: 2)
        let api = AccountStubAPI(
            account: .init(),
            tradingScreen: .init(open_orders: [], flags: .init(cancel_enabled: true))
        )
        let trading = makeTrading(makeService(api: api), wallet: wallet, api: api, tradingScreenReads: reads)
        let pending = PerpsPendingTradingAction(
            operationId: UUID().uuidString, walletId: wallet.id, marketId: 1, side: .long,
            payload: .autoCloseChange(.init(target: nil, restingOrderIndexes: [7]))
        )

        let result = await trading.reconcile(pending)
        XCTAssertEqual(result, .confirmed)
        let reload = Task {
            try await PerpsTkAccountReading(api: api, tradingScreenReads: reads)
                .tradingSnapshot(wallet: wallet, marketId: 1, positionId: nil)
        }
        await fulfillment(of: [decided], timeout: 2)
        release.finish()
        let snapshot = try await reload.value
        XCTAssertEqual(snapshot.orders?.triggerOrders, [])
        _ = try await earlier.value
    }

    func testARecordedApprovalIsNotSignedAgain() async throws {
        let vault = InMemoryKeychainVault()
        let wallet = makeWallet()
        try credentials(vault, wallet).saveIntegratorApproval(
            PerpsIntegratorApproval(key: approvalKey(), expiry: PerpsPlannerMapping.nowUnixMs() + 30 * 86_400_000)
        )
        let prompts = PromptCount()
        let service = makeService(api: AccountStubAPI(account: .init(), integrator: .tonkeeper), vault: vault)

        _ = try await service.prepareIntegratorApproval(
            wallet: wallet,
            session: session,
            passcodeProvider: { await prompts.cancel() }
        )

        let count = await prompts.count
        XCTAssertEqual(count, 0)
    }

    func testAMissingApprovalAsksForThePasscodeAndACancelSendsNothing() async throws {
        let prompts = PromptCount()
        let service = makeService(api: AccountStubAPI(account: .init(), integrator: .tonkeeper))

        do {
            _ = try await service.prepareIntegratorApproval(
                wallet: makeWallet(),
                session: session,
                passcodeProvider: { await prompts.cancel() }
            )
            XCTFail("a canceled passcode must not approve")
        } catch {
            XCTAssertEqual(error as? PerpsTradingError, .activationCanceled)
        }

        let count = await prompts.count
        XCTAssertEqual(count, 1)
    }

    func testAnUnreadableRecordIsSignedAgainInsteadOfFailingEveryTrade() async throws {
        let vault = InMemoryKeychainVault()
        let wallet = makeWallet()
        try vault.set(
            Data("not an approval".utf8),
            query: TKKeychainQuery(
                item: .genericPassword(
                    service: "LighterCredentials",
                    account: "\(wallet.id)/\(PerpsEnvironment.storage)/integratorApproval"
                ),
                accessGroup: nil,
                biometry: .none,
                accessible: .whenUnlockedThisDeviceOnly
            )
        )
        let prompts = PromptCount()
        let service = makeService(api: AccountStubAPI(account: .init(), integrator: .tonkeeper), vault: vault)

        do {
            _ = try await service.prepareIntegratorApproval(
                wallet: wallet,
                session: session,
                passcodeProvider: { await prompts.cancel() }
            )
            XCTFail("a canceled passcode must not approve")
        } catch {
            XCTAssertEqual(error as? PerpsTradingError, .activationCanceled)
        }

        let count = await prompts.count
        XCTAssertEqual(count, 1)
    }

    func testAnApprovalAboutToExpireIsSignedAgain() async throws {
        let vault = InMemoryKeychainVault()
        let wallet = makeWallet()
        try credentials(vault, wallet).saveIntegratorApproval(
            PerpsIntegratorApproval(key: approvalKey(), expiry: PerpsPlannerMapping.nowUnixMs() + 3_600_000)
        )
        let prompts = PromptCount()
        let service = makeService(api: AccountStubAPI(account: .init(), integrator: .tonkeeper), vault: vault)

        _ = try? await service.prepareIntegratorApproval(
            wallet: wallet,
            session: session,
            passcodeProvider: { await prompts.cancel() }
        )

        let count = await prompts.count
        XCTAssertEqual(count, 1)
    }

    func testAShortLivedApprovalIsKeptForMostOfItsLife() async throws {
        let vault = InMemoryKeychainVault()
        let wallet = makeWallet()
        try credentials(vault, wallet).saveIntegratorApproval(
            PerpsIntegratorApproval(key: approvalKey(), expiry: PerpsPlannerMapping.nowUnixMs() + 3 * 3_600_000)
        )
        let prompts = PromptCount()
        let service = makeService(
            api: AccountStubAPI(account: .init(), integrator: .tonkeeper(approvalTtlMs: 4 * 3_600_000)),
            vault: vault
        )

        _ = try await service.prepareIntegratorApproval(
            wallet: wallet,
            session: session,
            passcodeProvider: { await prompts.cancel() }
        )

        let count = await prompts.count
        XCTAssertEqual(count, 0)
    }

    func testARaisedFeeCeilingIsSignedAgain() async throws {
        let vault = InMemoryKeychainVault()
        let wallet = makeWallet()
        try credentials(vault, wallet).saveIntegratorApproval(
            PerpsIntegratorApproval(
                key: approvalKey(maxPerpsTakerFee: 900),
                expiry: PerpsPlannerMapping.nowUnixMs() + 30 * 86_400_000
            )
        )
        let prompts = PromptCount()
        let service = makeService(api: AccountStubAPI(account: .init(), integrator: .tonkeeper), vault: vault)

        _ = try? await service.prepareIntegratorApproval(
            wallet: wallet,
            session: session,
            passcodeProvider: { await prompts.cancel() }
        )

        let count = await prompts.count
        XCTAssertEqual(count, 1)
    }

    func testAnIntegratorSwitchedOffForgetsTheApproval() async throws {
        let vault = InMemoryKeychainVault()
        let wallet = makeWallet()
        let store = credentials(vault, wallet)
        try store.saveIntegratorApproval(
            PerpsIntegratorApproval(key: approvalKey(), expiry: PerpsPlannerMapping.nowUnixMs() + 30 * 86_400_000)
        )
        let prompts = PromptCount()
        let service = makeService(api: AccountStubAPI(account: .init(), integrator: .none), vault: vault)

        _ = try await service.prepareIntegratorApproval(
            wallet: wallet,
            session: session,
            passcodeProvider: { await prompts.cancel() }
        )

        let count = await prompts.count
        XCTAssertEqual(count, 0)
        XCTAssertNil(try store.loadIntegratorApproval())
    }

    func testAnOrderRefusedAfterAcceptedLeverageAsksForApprovalAndACancelClearsThePending() async throws {
        let vault = InMemoryKeychainVault()
        let wallet = makeWallet(id: UUID().uuidString)
        let store = credentials(vault, wallet)
        let privateKey = Data(repeating: 0xAB, count: 40)
        try store.saveL2PrivateKey(privateKey)
        try store.saveAccount(PerpsStoredAccount(accountIndex: session.accountIndex, apiKeyIndex: session.apiKeyIndex, keyDerivationIndex: 0))
        try store.saveIntegratorApproval(
            PerpsIntegratorApproval(key: approvalKey(), expiry: PerpsPlannerMapping.nowUnixMs() + 30 * 86_400_000)
        )
        let privateKeyHex = privateKey.map { String(format: "%02x", $0) }.joined()
        let sent = SentApprovals()
        let api = AccountStubAPI(
            account: .init(),
            integrator: .tonkeeper,
            nonce: 287,
            tradingScreen: .init(
                market: .init(
                    market_index: 1, symbol: "ETH", quote_asset: "USDC", status: "active",
                    price_decimals: 2, size_decimals: 4, tick_size: "0.01", step_size: "0.0001", min_size_base: "0.001", min_size_quote: "10", max_leverage: 25,
                    maker_fee_pct: "0.02", taker_fee_pct: "0.04", initial_margin_fraction: 400,
                    maintenance_margin_fraction: 300, mark_price: "2000"
                ),
                open_orders: [],
                balance: .init(available_balance: "1000"),
                flags: .init(open_enabled: true, cancel_enabled: true)
            ),
            orderBook: .init(
                updated_at: Date(), truncated: true,
                bids: [.init(price: "1999", size: "10")], asks: [.init(price: "2000", size: "10")]
            ),
            onSendTransactions: { _, transactions in
                await sent.record(transactions)
                guard transactions[0].tx_type == LighterConstants.shared.TxTypeL2UpdateLeverage else {
                    throw PerpsAPIError.badStatus(.init(
                        httpStatus: 400, code: "validation_error", message: nil,
                        retryable: false, reason: "integrator_not_approved"
                    ))
                }
                let hash = try await Self.transactionHash(transactions[0], privateKeyHex: privateKeyHex)
                return .init(transactions: [.init(tx_type: transactions[0].tx_type, tx_hash: hash)])
            }
        )
        let service = makeService(api: api, vault: vault)
        let trading = makeTrading(service, wallet: wallet, api: api)
        let prepared = try await trading.prepareOpen(.init(
            marketId: 1, side: .long, marginUsd: "100", leverage: 10, maxSlippage: 0.01,
            autoClose: .init(takeProfit: .init(triggerPrice: 2100), stopLoss: nil),
            takeProfitROIPercent: 20
        ))
        let prompts = PromptCount()

        let result = await trading.submit(prepared, passcodeProvider: { await prompts.cancel() })

        if case let .failed(error) = result {
            XCTAssertEqual(error, .activationCanceled)
        } else {
            XCTFail("a refused order must request approval even after leverage was accepted")
        }
        let promptCount = await prompts.count
        let transactions = await sent.transactions
        let journal = makeJournal(wallet)
        let pending = try await journal.pending(operationId: prepared.operationId)
        XCTAssertEqual(promptCount, 1)
        XCTAssertEqual(transactions.count, 2)
        XCTAssertEqual(transactions.first?.tx_type, LighterConstants.shared.TxTypeL2UpdateLeverage)
        XCTAssertNil(pending)
        let remaining = try await journal.allPending()
        XCTAssertTrue(remaining.isEmpty, "a dropped entry must take its TP/SL correction with it")
        XCTAssertNil(try store.loadIntegratorApproval())
        try await journal.removePending(operationId: prepared.operationId, includingFollowUps: true)
    }

    func testACancelGoesOnWhenTheOrderRestsButTheScreenMissedIt() async throws {
        let vault = InMemoryKeychainVault()
        let wallet = makeWallet(id: UUID().uuidString)
        let store = credentials(vault, wallet)
        try store.saveL2PrivateKey(Data(repeating: 0xAB, count: 40))
        try store.saveAccount(PerpsStoredAccount(accountIndex: session.accountIndex, apiKeyIndex: session.apiKeyIndex, keyDerivationIndex: 0))
        let resting = Components.Schemas.Order(
            id: "lighter:7", order_index: 7, market_index: 1, side: .long, _type: .limit, status: .open,
            category: .open, base_size: "0.5", price: "1900"
        )
        let api = AccountStubAPI(
            account: .init(),
            orderDetail: .init(order: resting, resting: true, fills: [], fills_known: true),
            integrator: .tonkeeper,
            tradingScreen: Self.tradingScreen(),
            orderBook: Self.orderBook()
        )
        let trading = makeTrading(makeService(api: api, vault: vault), wallet: wallet, api: api)

        let prepared = try await trading.prepareLimitOrderChange(
            .cancel(marketId: 1, orderIndex: 7, orderId: "lighter:7")
        ).get()

        XCTAssertEqual(prepared.review.order.orderIndex, 7)
    }

    func testAnEditGoesOnWhenTheOrderRestsButTheScreenMissedIt() async throws {
        let vault = InMemoryKeychainVault()
        let wallet = makeWallet(id: UUID().uuidString)
        let store = credentials(vault, wallet)
        try store.saveL2PrivateKey(Data(repeating: 0xAB, count: 40))
        try store.saveAccount(PerpsStoredAccount(accountIndex: session.accountIndex, apiKeyIndex: session.apiKeyIndex, keyDerivationIndex: 0))
        let resting = Components.Schemas.Order(
            id: "lighter:7", order_index: 7, market_index: 1, side: .long, _type: .limit, status: .open,
            category: .open, base_size: "0.5", price: "1900"
        )
        let api = AccountStubAPI(
            account: .init(),
            orderDetail: .init(order: resting, resting: true, fills: [], fills_known: true),
            integrator: .tonkeeper,
            tradingScreen: Self.tradingScreen(),
            orderBook: Self.orderBook()
        )
        let trading = makeTrading(makeService(api: api, vault: vault), wallet: wallet, api: api)

        let prepared = try await trading.prepareLimitOrderChange(
            .modify(marketId: 1, orderIndex: 7, limitPrice: 1950, baseAmount: 0.5, orderId: "lighter:7")
        ).get()

        XCTAssertEqual(prepared.review.order.orderIndex, 7)
        XCTAssertEqual(prepared.review.limitPrice, 1950)
        XCTAssertEqual(prepared.review.baseAmount, 0.5)
    }

    func testAnEditNeverSignsMoreThanTheSizeShownBeforeIt() async throws {
        let (wallet, vault) = try rebaseWallet()
        let sent = SentApprovals()
        func trading(restingSize: String) -> PerpsTkTradingService {
            var screen = Self.tradingScreen()
            screen.open_orders = [.init(
                id: "lighter:7", order_index: 7, market_index: 1, side: .long, _type: .limit, status: .open,
                category: .open, base_size: restingSize, price: "1900"
            )]
            let api = AccountStubAPI(
                account: .init(), nonce: 287, tradingScreen: screen, orderBook: Self.orderBook(),
                onSendTransactions: { _, transactions in
                    await sent.record(transactions)
                    throw PerpsAPIError.transport(underlying: URLError(.timedOut))
                }
            )
            return makeTrading(makeService(api: api, vault: vault), wallet: wallet, api: api)
        }
        let edit = PerpsLimitOrderChangeIntent.modify(marketId: 1, orderIndex: 7, limitPrice: 1950, baseAmount: 0.5, orderId: "lighter:7")

        let grown = await trading(restingSize: "0.8").prepareLimitOrderChange(edit)
        let reviewed = try await trading(restingSize: "0.4").prepareLimitOrderChange(edit).get()
        let submitted = await trading(restingSize: "0.5").submit(reviewed, passcodeProvider: { nil })

        guard case .failure(.stalePreparedTransaction) = grown else {
            return XCTFail("a size above the one shown must refuse the review, got \(grown)")
        }
        XCTAssertEqual(reviewed.review.baseAmount, 0.4)
        guard case .failed(.stalePreparedTransaction) = submitted else {
            return XCTFail("a size above the reviewed one must refuse the submit, got \(submitted)")
        }
        let sends = await sent.transactions
        XCTAssertTrue(sends.isEmpty)
    }

    func testAnOrderLookupThatFailsSaysWhyInsteadOfCallingTheOrderGone() async throws {
        let vault = InMemoryKeychainVault()
        let wallet = makeWallet(id: UUID().uuidString)
        let store = credentials(vault, wallet)
        try store.saveL2PrivateKey(Data(repeating: 0xAB, count: 40))
        try store.saveAccount(PerpsStoredAccount(accountIndex: session.accountIndex, apiKeyIndex: session.apiKeyIndex, keyDerivationIndex: 0))
        let offline = AccountStubAPI(
            account: .init(),
            orderError: .transport(underlying: URLError(.notConnectedToInternet)),
            integrator: .tonkeeper,
            tradingScreen: Self.tradingScreen(),
            orderBook: Self.orderBook()
        )
        let missing = AccountStubAPI(
            account: .init(),
            orderError: .notFound,
            integrator: .tonkeeper,
            tradingScreen: Self.tradingScreen(),
            orderBook: Self.orderBook()
        )
        let offlineTrading = makeTrading(makeService(api: offline, vault: vault), wallet: wallet, api: offline)
        let missingTrading = makeTrading(makeService(api: missing, vault: vault), wallet: wallet, api: missing)

        let edit = await offlineTrading.prepareLimitOrderChange(.modify(marketId: 1, orderIndex: 7, limitPrice: 1950, baseAmount: 0.5, orderId: "lighter:7"))
        let cancel = await offlineTrading.prepareLimitOrderChange(.cancel(marketId: 1, orderIndex: 7, orderId: "lighter:7"))
        let gone = await missingTrading.prepareLimitOrderChange(.modify(marketId: 1, orderIndex: 7, limitPrice: 1950, baseAmount: 0.5, orderId: "lighter:7"))

        guard case let .failure(editError) = edit, case let .failure(cancelError) = cancel, case let .failure(goneError) = gone else {
            return XCTFail("expected every change to fail, got \(edit), \(cancel) and \(gone)")
        }
        XCTAssertEqual(editError, .offline)
        XCTAssertEqual(cancelError, .offline)
        XCTAssertEqual(goneError, .orderNotFound)
    }

    func testRecoveryJournalsAnUnsentStepAsSendingBeforeItsSendAndAcceptedAfterIt() async throws {
        let vault = InMemoryKeychainVault()
        let wallet = makeWallet(id: UUID().uuidString)
        let store = credentials(vault, wallet)
        try store.saveL2PrivateKey(Data(repeating: 0xAB, count: 40))
        try store.saveAccount(PerpsStoredAccount(accountIndex: session.accountIndex, apiKeyIndex: session.apiKeyIndex, keyDerivationIndex: 0))
        let operationId = UUID().uuidString
        let step = PerpsPendingSignedStep(
            stepId: "open", attemptId: UUID().uuidString, nonce: 287,
            transactionExpiryUnixMs: PerpsPlannerMapping.nowUnixMs() + 600_000,
            txType: 14, txInfo: "{\"Nonce\":287}", txHash: "0xabc", state: .signed
        )
        let journal = PerpsPendingJournal(walletId: wallet.id, environment: PerpsEnvironment.storage)
        _ = try await journal.savePendingIfAbsentWithStatus(PerpsPendingTradingAction(
            operationId: operationId, walletId: wallet.id, marketId: 1, side: .long,
            payload: .open(limitPrice: nil),
            orderRefs: [.init(role: .parent, clientOrderIndex: 77)],
            signedSteps: [step]
        ))
        let sent = SentApprovals()
        let journaled = JournaledStates()
        let api = AccountStubAPI(
            account: .init(),
            onSendTransactions: { _, transactions in
                await sent.record(transactions)
                try await journaled.record(await journal.pending(operationId: operationId)?.signedSteps?.map(\.state))
                return .init(transactions: [.init(tx_type: transactions[0].tx_type, tx_hash: "abc")])
            }
        )
        let trading = makeTrading(makeService(api: api, vault: vault), wallet: wallet, api: api)

        _ = await trading.recoverInterruptedOperations()

        let transactions = await sent.transactions
        let statesAtSend = await journaled.states
        let recovered = try await journal.pending(operationId: operationId)
        XCTAssertEqual(transactions.map(\.tx_info), [step.txInfo])
        XCTAssertEqual(statesAtSend, [[.sending]])
        XCTAssertEqual(recovered?.signedSteps?.map(\.state), [.accepted])
        try await journal.removePending(operationId: operationId)
    }

    func testRecoveryResendsAStepUnderTheMultichainWalletId() async throws {
        let vault = InMemoryKeychainVault()
        let wallet = makeWallet(id: UUID().uuidString, multichainId: "multichain-wallet-id")
        let store = credentials(vault, wallet)
        try store.saveL2PrivateKey(Data(repeating: 0xAB, count: 40))
        try store.saveAccount(PerpsStoredAccount(accountIndex: session.accountIndex, apiKeyIndex: session.apiKeyIndex, keyDerivationIndex: 0))
        let operationId = UUID().uuidString
        let journal = PerpsPendingJournal(walletId: wallet.id, environment: PerpsEnvironment.storage)
        _ = try await journal.savePendingIfAbsentWithStatus(PerpsPendingTradingAction(
            operationId: operationId, walletId: wallet.id, marketId: 1, side: .long,
            payload: .open(limitPrice: nil),
            orderRefs: [.init(role: .parent, clientOrderIndex: 77)],
            signedSteps: [PerpsPendingSignedStep(
                stepId: "open", attemptId: UUID().uuidString, nonce: 287,
                transactionExpiryUnixMs: PerpsPlannerMapping.nowUnixMs() + 600_000,
                txType: 14, txInfo: "{\"Nonce\":287}", txHash: "0xabc", state: .signed
            )]
        ))
        let (sentFor, send) = AsyncStream<String>.makeStream()
        let api = AccountStubAPI(
            account: .init(),
            onSendTransactions: { walletId, transactions in
                send.yield(walletId)
                return .init(transactions: [.init(tx_type: transactions[0].tx_type, tx_hash: "abc")])
            }
        )
        let trading = makeTrading(makeService(api: api, vault: vault), wallet: wallet, api: api)

        _ = await trading.recoverInterruptedOperations()

        send.finish()
        var walletIds = [String]()
        for await walletId in sentFor {
            walletIds.append(walletId)
        }
        XCTAssertEqual(walletIds, ["multichain-wallet-id"])
        try await journal.removePending(operationId: operationId)
    }

    func testARecoveryPassOverAnEmptyJournalReadsNoKeychainAndTakesNoLane() async throws {
        let vault = InMemoryKeychainVault()
        let wallet = makeWallet(id: UUID().uuidString)
        let store = credentials(vault, wallet)
        try store.saveL2PrivateKey(Data(repeating: 0xAB, count: 40))
        try store.saveAccount(PerpsStoredAccount(accountIndex: session.accountIndex, apiKeyIndex: session.apiKeyIndex, keyDerivationIndex: 0))
        let api = AccountStubAPI(account: .init())
        let service = makeService(api: api, vault: vault)
        let trading = makeTrading(service, wallet: wallet, api: api)
        let lane = await service.submitLanes.lane(for: session)
        let held = expectation(description: "another operation holds the lane")
        let (laneReleases, releaseLane) = AsyncStream<Void>.makeStream()
        let holder = Task {
            try await lane.run {
                held.fulfill()
                for await _ in laneReleases {}
            }
        }
        await fulfillment(of: [held], timeout: 2)
        let readsBefore = vault.readCount

        let passed = expectation(description: "the pass ended without waiting for the lane")
        let pass = Task {
            let done = await trading.recoverInterruptedOperations()
            passed.fulfill()
            return done
        }
        await fulfillment(of: [passed], timeout: 2)
        releaseLane.finish()

        let done = await pass.value
        XCTAssertTrue(done)
        XCTAssertEqual(vault.readCount, readsBefore)
        try await holder.value
    }

    func testARecoveryRequestSendsAnInterruptedStepAndSettlesItsOperation() async throws {
        let vault = InMemoryKeychainVault()
        let wallet = makeWallet(id: UUID().uuidString)
        let store = credentials(vault, wallet)
        try store.saveL2PrivateKey(Data(repeating: 0xAB, count: 40))
        try store.saveAccount(PerpsStoredAccount(accountIndex: session.accountIndex, apiKeyIndex: session.apiKeyIndex, keyDerivationIndex: 0))
        let operationId = UUID().uuidString
        let step = PerpsPendingSignedStep(
            stepId: "cancel", attemptId: UUID().uuidString, nonce: 287,
            transactionExpiryUnixMs: PerpsPlannerMapping.nowUnixMs() + 600_000,
            txType: 15, txInfo: "{\"Nonce\":287}", txHash: "0xabc", state: .signed
        )
        let journal = PerpsPendingJournal(walletId: wallet.id, environment: PerpsEnvironment.storage)
        _ = try await journal.savePendingIfAbsentWithStatus(PerpsPendingTradingAction(
            operationId: operationId, walletId: wallet.id, marketId: 1, side: .long,
            payload: .autoCloseChange(.init(target: nil, restingOrderIndexes: [7])),
            signedSteps: [step]
        ))
        let sent = SentApprovals()
        let api = AccountStubAPI(
            account: .init(),
            tradingScreen: .init(open_orders: [], flags: .init(cancel_enabled: true)),
            onSendTransactions: { _, transactions in
                await sent.record(transactions)
                return .init(transactions: [.init(tx_type: transactions[0].tx_type, tx_hash: "abc")])
            }
        )
        let trading = makeTrading(makeService(api: api, vault: vault), wallet: wallet, api: api)
        let (passes, passed) = AsyncStream<Bool>.makeStream()
        let recovery = PerpsTradingRecovery(
            recover: {
                let done = await trading.recoverInterruptedOperations()
                passed.yield(done)
                return done
            },
            renewAutoClose: { _ in true }
        )

        recovery.recover()

        var results = passes.makeAsyncIterator()
        let done = await results.next()
        let transactions = await sent.transactions
        let left = try await journal.pending(operationId: operationId)
        XCTAssertEqual(done, true)
        XCTAssertEqual(transactions.map(\.tx_info), [step.txInfo])
        XCTAssertNil(left)
        withExtendedLifetime(recovery) {}
    }

    func testLettingTheScopeGoCancelsTheRecoveryItStarted() async throws {
        let vault = InMemoryKeychainVault()
        let wallet = makeWallet(id: UUID().uuidString)
        let store = credentials(vault, wallet)
        try store.saveL2PrivateKey(Data(repeating: 0xAB, count: 40))
        try store.saveAccount(PerpsStoredAccount(accountIndex: session.accountIndex, apiKeyIndex: session.apiKeyIndex, keyDerivationIndex: 0))
        let operationId = UUID().uuidString
        let journal = PerpsPendingJournal(walletId: wallet.id, environment: PerpsEnvironment.storage)
        _ = try await journal.savePendingIfAbsentWithStatus(PerpsPendingTradingAction(
            operationId: operationId, walletId: wallet.id, marketId: 1, side: .long,
            payload: .open(limitPrice: nil),
            orderRefs: [.init(role: .parent, clientOrderIndex: 77)],
            signedSteps: [PerpsPendingSignedStep(
                stepId: "open", attemptId: UUID().uuidString, nonce: 287,
                transactionExpiryUnixMs: PerpsPlannerMapping.nowUnixMs() + 600_000,
                txType: 14, txInfo: "{\"Nonce\":287}", txHash: "0xabc", state: .signed
            )]
        ))
        let sendStarted = expectation(description: "the recovery is sending the interrupted step")
        let sendCancelled = expectation(description: "the send was cancelled with the scope")
        let (neverAnswered, answer) = AsyncStream<Void>.makeStream()
        defer { answer.finish() }
        let api = AccountStubAPI(
            account: .init(account_index: Int(session.accountIndex), has_l2_key: true, has_ro_token: true),
            balance: .init(available_balance: "100"),
            onSendTransactions: { _, _ in
                sendStarted.fulfill()
                await withTaskCancellationHandler {
                    for await _ in neverAnswered {}
                } onCancel: {
                    sendCancelled.fulfill()
                }
                throw CancellationError()
            }
        )
        var scope: PerpsWalletScope? = PerpsWalletScope(
            wallet: wallet,
            accountService: makeService(api: api, vault: vault),
            perpsAPI: api,
            multichainService: MultichainServiceFake(),
            historyEvents: PerpsHistoryEvents { false },
            markPriceProvider: { _ in nil },
            marketProvider: { _ in nil },
            markPrices: { _ in AsyncStream { $0.finish() } },
            perpsSignals: { _ in AsyncStream { $0.finish() } },
            isRealtimeEnabled: { false }
        )
        weak let released = scope
        scope?.accountStore.resolveIfNeeded()
        await fulfillment(of: [sendStarted], timeout: 5)
        await scope?.accountStore.resolveTaskForTesting?.value

        scope = nil

        XCTAssertNil(released)
        await fulfillment(of: [sendCancelled], timeout: 2)
        try await journal.removePending(operationId: operationId)
    }

    func testSubmittingAnOperationAsksForRecoveryOnceItIsJournaled() async throws {
        let vault = InMemoryKeychainVault()
        let wallet = makeWallet(id: UUID().uuidString)
        let store = credentials(vault, wallet)
        try store.saveL2PrivateKey(Data(repeating: 0xAB, count: 40))
        try store.saveAccount(PerpsStoredAccount(accountIndex: session.accountIndex, apiKeyIndex: session.apiKeyIndex, keyDerivationIndex: 0))
        try store.saveIntegratorApproval(
            PerpsIntegratorApproval(key: approvalKey(), expiry: PerpsPlannerMapping.nowUnixMs() + 30 * 86_400_000)
        )
        let api = AccountStubAPI(
            account: .init(),
            integrator: .tonkeeper,
            nonce: 287,
            tradingScreen: Self.tradingScreen(),
            orderBook: Self.orderBook(),
            onSendTransactions: { _, _ in
                throw PerpsAPIError.badStatus(.init(
                    httpStatus: 400, code: "validation_error", message: nil, retryable: false, reason: nil
                ))
            }
        )
        let service = makeService(api: api, vault: vault)
        let journal = makeJournal(wallet)
        let (requests, requestRecovery) = AsyncStream<Void>.makeStream()
        let trading = makeTrading(service, wallet: wallet, api: api, operationJournaled: { requestRecovery.yield() })
        let prepared = try await trading.prepareOpen(.init(
            marketId: 1, side: .long, marginUsd: "100", leverage: 10, maxSlippage: 0.01, autoClose: nil
        ))

        _ = await trading.submit(prepared, passcodeProvider: { nil })

        requestRecovery.finish()
        var count = 0
        for await _ in requests {
            count += 1
        }
        XCTAssertEqual(count, 1)
        try await journal.removePending(operationId: prepared.operationId)
    }

    func testAnOpenRefusedOverItsRegionFailsAtOnceAndLeavesNothingPending() async throws {
        let refusals: [(status: Int, code: String, error: PerpsTradingError)] = [
            (400, "region_restricted", .regionUnavailable),
            (503, "region_check_unavailable", .serverUnavailable),
        ]
        for refusal in refusals {
            let vault = InMemoryKeychainVault()
            let wallet = makeWallet(id: UUID().uuidString)
            let store = credentials(vault, wallet)
            let privateKey = Data(repeating: 0xAB, count: 40)
            try store.saveL2PrivateKey(privateKey)
            try store.saveAccount(PerpsStoredAccount(accountIndex: session.accountIndex, apiKeyIndex: session.apiKeyIndex, keyDerivationIndex: 0))
            try store.saveIntegratorApproval(
                PerpsIntegratorApproval(key: approvalKey(), expiry: PerpsPlannerMapping.nowUnixMs() + 30 * 86_400_000)
            )
            let privateKeyHex = privateKey.map { String(format: "%02x", $0) }.joined()
            let (status, code) = (refusal.status, refusal.code)
            let api = AccountStubAPI(
                account: .init(),
                integrator: .tonkeeper,
                nonce: 287,
                tradingScreen: Self.tradingScreen(),
                orderBook: Self.orderBook(),
                onSendTransactions: { _, transactions in
                    guard transactions[0].tx_type == LighterConstants.shared.TxTypeL2UpdateLeverage else {
                        throw PerpsAPIError.badStatus(.init(
                            httpStatus: status, code: code, message: nil, retryable: status == 503, reason: nil
                        ))
                    }
                    let hash = try await Self.transactionHash(transactions[0], privateKeyHex: privateKeyHex)
                    return .init(transactions: [.init(tx_type: transactions[0].tx_type, tx_hash: hash)])
                }
            )
            let trading = makeTrading(makeService(api: api, vault: vault), wallet: wallet, api: api)
            let prepared = try await trading.prepareOpen(.init(
                marketId: 1, side: .long, marginUsd: "100", leverage: 10, maxSlippage: 0.01, autoClose: nil
            ))

            let result = await trading.submit(prepared, passcodeProvider: { nil })

            guard case let .failed(error) = result else {
                XCTFail("\(code) must fail the open, got \(result)")
                continue
            }
            XCTAssertEqual(error, refusal.error, code)
            let pending = try await makeJournal(wallet).pending(operationId: prepared.operationId)
            XCTAssertNil(pending, code)
        }
    }

    func testASubmitRefusedBeforeSendingEndsTheTradeItBegan() async throws {
        let vault = InMemoryKeychainVault()
        let wallet = makeWallet(id: UUID().uuidString)
        let store = credentials(vault, wallet)
        try store.saveL2PrivateKey(Data(repeating: 0xAB, count: 40))
        try store.saveAccount(PerpsStoredAccount(accountIndex: session.accountIndex, apiKeyIndex: session.apiKeyIndex, keyDerivationIndex: 0))
        let api = AccountStubAPI(
            account: .init(),
            onAccountTier: { .init(id: "1", name: "plus") },
            integrator: .tonkeeper,
            nonce: 287,
            tradingScreen: Self.tradingScreen(),
            orderBook: Self.orderBook()
        )
        let trades = TradeEvents()
        let trading = makeTrading(makeService(api: api, vault: vault), wallet: wallet, api: api, trades: trades)
        let prepared = try await trading.prepareOpen(.init(
            marketId: 1, side: .long, marginUsd: "100", leverage: 10, maxSlippage: 0.01, autoClose: nil
        ))

        let result = await trading.submit(prepared, passcodeProvider: { nil })

        guard case .failed(.activationCanceled) = result else { return XCTFail("the dismissed passcode must refuse the submit") }
        let events = trades.events
        let opening = PerpsOpeningDescriptor(
            marketId: 1, symbol: prepared.review.symbol, side: .long, marginUsd: prepared.review.marginUsd, leverage: 10, isLimit: false,
            liquidationPrice: prepared.review.liquidationPrice
        )
        XCTAssertLessThan(prepared.review.marginUsd, 100)
        XCTAssertEqual(events, [
            .began(prepared.operationId, marketId: 1, .opening(opening)),
            .settled(prepared.operationId, succeeded: false),
        ])
    }

    func testASettledOperationEndsItsTradeWithTheOutcome() async {
        let wallet = makeWallet(id: UUID().uuidString)
        let api = AccountStubAPI(
            account: .init(),
            tradingScreen: .init(open_orders: [], flags: .init(cancel_enabled: true))
        )
        let trades = TradeEvents()
        let trading = makeTrading(makeService(api: api), wallet: wallet, api: api, trades: trades)
        let pending = PerpsPendingTradingAction(
            operationId: UUID().uuidString, walletId: wallet.id, marketId: 1, side: .long,
            payload: .autoCloseChange(.init(target: nil, restingOrderIndexes: [7]))
        )

        let result = await trading.reconcile(pending)

        XCTAssertEqual(result, .confirmed)
        XCTAssertEqual(trades.events, [.settled(pending.operationId, succeeded: true)])
    }

    func testOnlyACloseThatFilledTheWholePositionReportsItClosed() async {
        for (filled, closes) in [("1", true), ("0.4", false)] {
            let wallet = makeWallet(id: UUID().uuidString)
            let api = AccountStubAPI(account: .init(), onPositionState: { _ in
                .init(market_index: 1, orders: [.init(order_index: 9, status: "filled", filled_base: filled)])
            })
            let trades = TradeEvents()
            let trading = makeTrading(makeService(api: api), wallet: wallet, api: api, trades: trades)
            let pending = PerpsPendingTradingAction(
                operationId: UUID().uuidString, walletId: wallet.id, marketId: 1, side: .long,
                payload: .close, expectedBaseSize: 1, orderRefs: [.init(role: .close, clientOrderIndex: 9)]
            )

            let result = await trading.reconcile(pending)

            XCTAssertEqual(result, closes ? .confirmed : .partiallyFilled, filled)
            XCTAssertEqual(
                trades.events,
                [.settled(pending.operationId, succeeded: true)] + (closes ? [.closed(pending.operationId)] : []),
                filled
            )
        }
    }

    func testWaitingForTheApprovalPasscodeHoldsNoOtherOperationOfTheAccountBack() async throws {
        let vault = InMemoryKeychainVault()
        let wallet = makeWallet(id: UUID().uuidString)
        let store = credentials(vault, wallet)
        try store.saveL2PrivateKey(Data(repeating: 0xAB, count: 40))
        try store.saveAccount(PerpsStoredAccount(accountIndex: session.accountIndex, apiKeyIndex: session.apiKeyIndex, keyDerivationIndex: 0))
        let api = AccountStubAPI(
            account: .init(),
            onAccountTier: { .init(id: "1", name: "plus") },
            integrator: .tonkeeper,
            nonce: 287,
            tradingScreen: Self.tradingScreen(),
            orderBook: Self.orderBook()
        )
        let trading = makeTrading(makeService(api: api, vault: vault), wallet: wallet, api: api)
        let prepared = try await trading.prepareOpen(.init(
            marketId: 1, side: .long, marginUsd: "100", leverage: 10, maxSlippage: 0.01, autoClose: nil
        ))
        let asked = expectation(description: "the approval asks for the passcode")
        let (passcodes, passcode) = AsyncStream<String?>.makeStream()
        let submit = Task {
            await trading.submit(prepared, passcodeProvider: {
                asked.fulfill()
                for await entered in passcodes {
                    return entered
                }
                return nil
            })
        }
        await fulfillment(of: [asked], timeout: 2)

        let recovered = expectation(description: "recovery runs while the passcode is being entered")
        let recovery = Task {
            _ = await trading.recoverInterruptedOperations()
            recovered.fulfill()
        }
        await fulfillment(of: [recovered], timeout: 2)
        passcode.yield(nil)

        let result = await submit.value
        await recovery.value
        guard case let .failed(error) = result else { return XCTFail("a canceled passcode must not submit") }
        XCTAssertEqual(error, .activationCanceled)
    }

    func testAWithdrawalDuringATradeWaitsForTheTradesStepsAndTakesTheNextNonce() async throws {
        let vault = InMemoryKeychainVault()
        let wallet = makeWallet(id: UUID().uuidString)
        let store = credentials(vault, wallet)
        try store.saveL2PrivateKey(Data(repeating: 0xAB, count: 40))
        try store.saveAccount(PerpsStoredAccount(accountIndex: session.accountIndex, apiKeyIndex: session.apiKeyIndex, keyDerivationIndex: 0))
        try store.saveIntegratorApproval(
            PerpsIntegratorApproval(key: approvalKey(), expiry: PerpsPlannerMapping.nowUnixMs() + 30 * 86_400_000)
        )
        let mnemonicAccess = try await savedMnemonicAccess(vault: vault, wallet: wallet)
        let journal = PerpsPendingJournal(walletId: wallet.id, environment: PerpsEnvironment.storage)
        let firstSend = expectation(description: "the trade's first step is on its way")
        let transferPriced = expectation(description: "the withdrawal checked the fee of the transfer it signs")
        transferPriced.assertForOverFulfill = false
        let (releases, release) = AsyncStream<Void>.makeStream()
        let sends = LaneSends(holdingFirstSendUntil: releases, announcing: firstSend)
        let api = AccountStubAPI(
            account: .init(account_index: Int(session.accountIndex), l1_address: Self.ethAddress),
            balance: .init(available_balance: "1000"),
            onAccountTier: { .init(id: "1", name: "plus") },
            integrator: .tonkeeper,
            nonce: 287,
            tradingScreen: Self.tradingScreen(),
            orderBook: Self.orderBook(),
            onSendTransactions: { _, transactions in
                try await sends.accept(transactions[0], journaledIn: journal)
            }
        )
        let service = makeService(api: api, vault: vault, mnemonicAccess: mnemonicAccess)
        let trading = makeTrading(service, wallet: wallet, api: api)
        let withdrawals = try XCTUnwrap(service.withdrawService(
            wallet: wallet,
            journal: makeJournal(wallet),
            recovery: service.fundingRecovery(wallet: wallet, journal: makeJournal(wallet)),
            readOnlyToken: makeReadOnlyToken(service, wallet),
            transferFeeUnits: { _, _ in
                transferPriced.fulfill()
                return nil
            },
            securityConfig: { Self.relaySecurity() }
        ))
        let prepared = try await trading.prepareOpen(.init(
            marketId: 1, side: .long, marginUsd: "100", leverage: 10, maxSlippage: 0.01, autoClose: nil
        ))
        let review = Self.usdcWithdrawReview(accountIndex: session.accountIndex)

        async let traded = trading.submit(prepared, passcodeProvider: { nil })
        await fulfillment(of: [firstSend], timeout: 5)
        async let withdrawn = withdrawals.pay(review: review, passcode: "1234")
        await fulfillment(of: [transferPriced], timeout: 5)
        try await Task.sleep(nanoseconds: 200_000_000)
        release.finish()
        let tradeResult = await traded
        let withdrawalId = try await withdrawn

        guard case let .submitted(trade) = tradeResult else { return XCTFail("the trade must be accepted: \(tradeResult)") }
        let withdrawal = try await journal.funding(operationId: withdrawalId)?.withdraw
        let sentNonces = await sends.nonces
        let overlapped = await sends.overlapped
        XCTAssertEqual(sentNonces, [287, 288, 289])
        XCTAssertFalse(overlapped, "the withdrawal was sent while a trade step of the same api key was in flight")
        XCTAssertEqual(trade.signedSteps?.map(\.nonce), [287, 288])
        XCTAssertEqual(withdrawal?.steps.last?.nonce, 289)
        XCTAssertEqual(withdrawal?.stage, .accepted)
        try await journal.removePending(operationId: prepared.operationId)
        try await journal.removeFunding(operationId: withdrawalId)
    }

    func testAWithdrawalRefusedForItsNonceStaysTrackedAndTheNextTradeReadsTheBackendNonce() async throws {
        let vault = InMemoryKeychainVault()
        let wallet = makeWallet(id: UUID().uuidString)
        let store = credentials(vault, wallet)
        try store.saveL2PrivateKey(Data(repeating: 0xAB, count: 40))
        try store.saveAccount(PerpsStoredAccount(accountIndex: session.accountIndex, apiKeyIndex: session.apiKeyIndex, keyDerivationIndex: 0))
        let mnemonicAccess = try await savedMnemonicAccess(vault: vault, wallet: wallet)
        let journal = PerpsPendingJournal(walletId: wallet.id, environment: PerpsEnvironment.storage)
        let api = AccountStubAPI(
            account: .init(account_index: Int(session.accountIndex), l1_address: Self.ethAddress),
            balance: .init(available_balance: "1000"),
            nonce: 289,
            onSendTransactions: { _, _ in
                throw PerpsAPIError.badStatus(
                    PerpsAPIFailure(httpStatus: 400, code: "validation_error", message: nil, retryable: false, reason: "resign_required")
                )
            }
        )
        let service = makeService(api: api, vault: vault, mnemonicAccess: mnemonicAccess)
        let withdrawals = try XCTUnwrap(service.withdrawService(
            wallet: wallet,
            journal: makeJournal(wallet),
            recovery: service.fundingRecovery(wallet: wallet, journal: makeJournal(wallet)),
            readOnlyToken: makeReadOnlyToken(service, wallet),
            transferFeeUnits: { _, _ in nil },
            securityConfig: { Self.relaySecurity() }
        ))
        let review = Self.usdcWithdrawReview(accountIndex: session.accountIndex)

        do {
            _ = try await withdrawals.pay(review: review, passcode: "1234")
            XCTFail("a refused withdrawal must not be reported as sent")
        } catch {
            XCTAssertEqual(error as? PerpsWithdrawServiceError, .nonceRefused)
            XCTAssertEqual(PerpsWithdrawService.message(for: error), .notSent)
        }

        let operation = try await journal.allFunding().first { $0.withdraw != nil }
        let withdraw = try XCTUnwrap(operation?.withdraw)
        XCTAssertEqual(withdraw.stage, .unknown)
        XCTAssertEqual(withdraw.failureReason, PerpsWithdrawService.resignRequiredReason)
        XCTAssertEqual(withdraw.steps.last?.state, .unknown)
        XCTAssertEqual(withdraw.steps.last?.nonce, 289)
        let nextTradeNonce = try await service.submitLanes.lane(for: session).nextNonce(walletId: wallet.id)
        XCTAssertEqual(nextTradeNonce, 289)
        if let operation {
            try await journal.removeFunding(operationId: operation.operationId)
        }
    }

    func testAWithdrawalSignsWithTheBackendNonceAfterAnotherDeviceUsedTheAccount() async throws {
        let vault = InMemoryKeychainVault()
        let wallet = makeWallet(id: UUID().uuidString)
        let store = credentials(vault, wallet)
        try store.saveL2PrivateKey(Data(repeating: 0xAB, count: 40))
        try store.saveAccount(PerpsStoredAccount(accountIndex: session.accountIndex, apiKeyIndex: session.apiKeyIndex, keyDerivationIndex: 0))
        let mnemonicAccess = try await savedMnemonicAccess(vault: vault, wallet: wallet)
        let journal = PerpsPendingJournal(walletId: wallet.id, environment: PerpsEnvironment.storage)
        let venueNonce = MovingNonce(287)
        let sent = expectation(description: "the withdrawal is sent")
        let (released, release) = AsyncStream<Void>.makeStream()
        release.finish()
        let sends = LaneSends(holdingFirstSendUntil: released, announcing: sent)
        let api = AccountStubAPI(
            account: .init(account_index: Int(session.accountIndex), l1_address: Self.ethAddress),
            balance: .init(available_balance: "1000"),
            onNextNonce: { try await venueNonce.read() },
            onSendTransactions: { _, transactions in
                try await sends.accept(transactions[0], journaledIn: journal)
            }
        )
        let service = makeService(api: api, vault: vault, mnemonicAccess: mnemonicAccess)
        let withdrawals = try XCTUnwrap(service.withdrawService(
            wallet: wallet,
            journal: makeJournal(wallet),
            recovery: service.fundingRecovery(wallet: wallet, journal: makeJournal(wallet)),
            readOnlyToken: makeReadOnlyToken(service, wallet),
            transferFeeUnits: { _, _ in nil },
            securityConfig: { Self.relaySecurity() }
        ))
        let lane = await service.submitLanes.lane(for: session)
        let earlierNonce = try await lane.nextNonce(walletId: wallet.id)
        await venueNonce.move(to: 300)

        let withdrawalId = try await withdrawals.pay(
            review: Self.usdcWithdrawReview(accountIndex: session.accountIndex),
            passcode: "1234"
        )

        await fulfillment(of: [sent], timeout: 5)
        let sentNonces = await sends.nonces
        let withdrawal = try await journal.funding(operationId: withdrawalId)?.withdraw
        XCTAssertEqual(earlierNonce, 287)
        XCTAssertEqual(sentNonces, [300])
        XCTAssertEqual(withdrawal?.stage, .accepted)
        try await journal.removeFunding(operationId: withdrawalId)
    }

    func testAWithdrawalIsNotSignedWithACachedNonceItCouldNotCheck() async throws {
        let vault = InMemoryKeychainVault()
        let wallet = makeWallet(id: UUID().uuidString)
        let store = credentials(vault, wallet)
        try store.saveL2PrivateKey(Data(repeating: 0xAB, count: 40))
        try store.saveAccount(PerpsStoredAccount(accountIndex: session.accountIndex, apiKeyIndex: session.apiKeyIndex, keyDerivationIndex: 0))
        let mnemonicAccess = try await savedMnemonicAccess(vault: vault, wallet: wallet)
        let journal = PerpsPendingJournal(walletId: wallet.id, environment: PerpsEnvironment.storage)
        let venueNonce = MovingNonce(287)
        let calls = WithdrawalCalls()
        let api = AccountStubAPI(
            account: .init(account_index: Int(session.accountIndex), l1_address: Self.ethAddress),
            balance: .init(available_balance: "1000"),
            onNextNonce: { try await venueNonce.read() },
            onSendTransactions: { _, transactions in
                try await calls.send(transactions[0], journaledIn: journal)
            }
        )
        let service = makeService(api: api, vault: vault, mnemonicAccess: mnemonicAccess)
        let withdrawals = try XCTUnwrap(service.withdrawService(
            wallet: wallet,
            journal: makeJournal(wallet),
            recovery: service.fundingRecovery(wallet: wallet, journal: makeJournal(wallet)),
            readOnlyToken: makeReadOnlyToken(service, wallet),
            transferFeeUnits: { _, _ in nil },
            securityConfig: { Self.relaySecurity() }
        ))
        _ = try await service.submitLanes.lane(for: session).nextNonce(walletId: wallet.id)
        await venueNonce.move(to: nil)

        do {
            _ = try await withdrawals.pay(review: Self.usdcWithdrawReview(accountIndex: session.accountIndex), passcode: "1234")
            XCTFail("a withdrawal must not be signed with a nonce the backend did not confirm")
        } catch {}

        let sent = await calls.sent
        let funding = try await journal.allFunding().filter { $0.withdraw != nil }
        XCTAssertTrue(sent.isEmpty)
        XCTAssertTrue(funding.isEmpty)
    }

    func testARetryAfterARefusalWhoseNonceReadFailsSaysTheServiceIsUnavailable() async throws {
        let vault = InMemoryKeychainVault()
        let wallet = makeWallet(id: UUID().uuidString)
        let store = credentials(vault, wallet)
        try store.saveL2PrivateKey(Data(repeating: 0xAB, count: 40))
        try store.saveAccount(PerpsStoredAccount(accountIndex: session.accountIndex, apiKeyIndex: session.apiKeyIndex, keyDerivationIndex: 0))
        let mnemonicAccess = try await savedMnemonicAccess(vault: vault, wallet: wallet)
        let journal = PerpsPendingJournal(walletId: wallet.id, environment: PerpsEnvironment.storage)
        let venueNonce = MovingNonce(289)
        let api = AccountStubAPI(
            account: .init(account_index: Int(session.accountIndex), l1_address: Self.ethAddress),
            balance: .init(available_balance: "1000"),
            onNextNonce: {
                guard let nonce = await venueNonce.value else { throw PerpsAPIError.transport(underlying: URLError(.timedOut)) }
                return nonce
            },
            onSendTransactions: { _, _ in
                throw PerpsAPIError.badStatus(
                    PerpsAPIFailure(httpStatus: 400, code: "validation_error", message: nil, retryable: false, reason: "resign_required")
                )
            }
        )
        let service = makeService(api: api, vault: vault, mnemonicAccess: mnemonicAccess)
        let withdrawals = try XCTUnwrap(service.withdrawService(
            wallet: wallet,
            journal: makeJournal(wallet),
            recovery: service.fundingRecovery(wallet: wallet, journal: makeJournal(wallet)),
            readOnlyToken: makeReadOnlyToken(service, wallet),
            transferFeeUnits: { _, _ in nil },
            securityConfig: { Self.relaySecurity() }
        ))
        let review = Self.usdcWithdrawReview(accountIndex: session.accountIndex)
        _ = try? await withdrawals.pay(review: review, passcode: "1234")
        await venueNonce.move(to: nil)

        do {
            _ = try await withdrawals.pay(review: review, passcode: "1234")
            XCTFail("a retry must not go out while the refused withdrawal cannot be checked")
        } catch {
            XCTAssertEqual(PerpsWithdrawService.message(for: error), .serviceUnavailable)
        }

        let funding = try await journal.allFunding().filter { $0.withdraw != nil }
        XCTAssertEqual(funding.count, 1)
        for operation in funding {
            try await journal.removeFunding(operationId: operation.operationId)
        }
    }

    func testARefusedNonceAndAnUnsettledWithdrawalTellTheUserWhatToDo() {
        XCTAssertEqual(PerpsWithdrawService.message(for: PerpsWithdrawServiceError.nonceRefused), .notSent)
        XCTAssertEqual(PerpsWithdrawService.message(for: PerpsWithdrawServiceError.paymentInFlight), .inFlight)
    }

    func testAWithdrawalIsNeitherQuotedNorSignedWithoutASignedRelayAccount() async throws {
        for security in [nil, Self.relaySecurity([])] {
            let withdrawal = try await relayWithdrawal(security: security)

            do {
                _ = try await withdrawal.service.review(
                    destination: PerpsFundingAsset(assetId: PerpsFundingAssetId.usdcEthereum, symbol: "USDC", decimals: 6),
                    recipient: Self.ethAddress,
                    amount: "10"
                )
                XCTFail("a withdrawal with no Relay account to check must not be quoted")
            } catch {
                XCTAssertEqual(error as? PerpsWithdrawServiceError, .noRelayAccount)
                XCTAssertEqual(PerpsWithdrawService.message(for: error), .serviceUnavailable)
            }
            do {
                _ = try await withdrawal.service.pay(review: Self.usdcWithdrawReview(accountIndex: session.accountIndex), passcode: "1234")
                XCTFail("a withdrawal with no Relay account to check must not be signed")
            } catch {
                XCTAssertEqual(error as? PerpsWithdrawServiceError, .noRelayAccount)
            }

            let quoted = await withdrawal.calls.quotes
            let sent = await withdrawal.calls.sent
            let journaled = try await withdrawal.journal.allFunding()
            XCTAssertEqual(quoted, 0)
            XCTAssertEqual(sent, [])
            XCTAssertTrue(journaled.isEmpty)
        }
    }

    func testAShownQuoteToAnAccountTheConfigNoLongerNamesIsQuotedAgainUnsigned() async throws {
        let withdrawal = try await relayWithdrawal(security: Self.relaySecurity([Self.otherRelayAccount]))

        do {
            _ = try await withdrawal.service.pay(review: Self.usdcWithdrawReview(accountIndex: session.accountIndex), passcode: "1234")
            XCTFail("a transfer to an account the config does not name must not be signed")
        } catch {
            XCTAssertEqual(error as? PerpsWithdrawServiceError, .quoteExpired)
            XCTAssertEqual(PerpsWithdrawService.message(for: error), .quoteExpired)
        }

        let quoted = await withdrawal.calls.quotes
        let sent = await withdrawal.calls.sent
        let journaled = try await withdrawal.journal.allFunding()
        XCTAssertEqual(quoted, 0)
        XCTAssertEqual(sent, [])
        XCTAssertTrue(journaled.isEmpty)
    }

    func testARenewedQuoteToAnotherAccountIsNotSigned() async throws {
        let renewedTo: [Int64] = [Self.otherRelayAccount, 555_555]
        for toAccountIndex in renewedTo {
            let withdrawal = try await relayWithdrawal(
                security: Self.relaySecurity([Self.relayAccount, Self.otherRelayAccount]),
                renewed: Self.renewedWithdrawQuote(accountIndex: session.accountIndex, toAccountIndex: toAccountIndex)
            )

            do {
                _ = try await withdrawal.service.pay(review: Self.usdcWithdrawReview(accountIndex: session.accountIndex, expiresIn: 5), passcode: "1234")
                XCTFail("a renewed transfer to account \(toAccountIndex) must not be signed")
            } catch {
                XCTAssertEqual(error as? PerpsWithdrawQuoteError, .notRelayAccount)
                XCTAssertEqual(PerpsWithdrawService.message(for: error), .failed)
            }

            let quoted = await withdrawal.calls.quotes
            let sent = await withdrawal.calls.sent
            let journaled = try await withdrawal.journal.allFunding()
            XCTAssertEqual(quoted, 1)
            XCTAssertEqual(sent, [])
            XCTAssertTrue(journaled.isEmpty)
        }
    }

    func testARenewedQuoteWithAHigherFeeIsReviewedAgain() async throws {
        let withdrawal = try await relayWithdrawal(
            security: Self.relaySecurity(),
            renewed: Self.renewedWithdrawQuote(accountIndex: session.accountIndex, feeUnits: "1")
        )

        do {
            _ = try await withdrawal.service.pay(review: Self.usdcWithdrawReview(accountIndex: session.accountIndex, expiresIn: 5), passcode: "1234")
            XCTFail("a renewed transfer with a higher fee must not be signed unshown")
        } catch {
            XCTAssertEqual(error as? PerpsWithdrawServiceError, .feeChanged)
            XCTAssertEqual(PerpsWithdrawService.message(for: error), .quoteExpired)
        }

        let sent = await withdrawal.calls.sent
        XCTAssertEqual(sent, [])
    }

    func testARenewedQuoteDebitingMoreThanTheShownOneIsReviewedAgain() async throws {
        let withdrawal = try await relayWithdrawal(
            security: Self.relaySecurity(),
            renewed: Self.renewedWithdrawQuote(accountIndex: session.accountIndex, amount: "9500000")
        )

        do {
            _ = try await withdrawal.service.pay(
                review: Self.usdcWithdrawReview(accountIndex: session.accountIndex, expiresIn: 5, transferUnits: 9_000_000),
                passcode: "1234"
            )
            XCTFail("a renewed transfer debiting more than shown must not be signed unshown")
        } catch {
            XCTAssertEqual(error as? PerpsWithdrawServiceError, .quoteExpired)
            XCTAssertEqual(PerpsWithdrawService.message(for: error), .quoteExpired)
        }

        let sent = await withdrawal.calls.sent
        XCTAssertEqual(sent, [])
    }

    func testARenewedQuoteToTheShownRelayAccountAtNoHigherFeeIsSigned() async throws {
        let withdrawal = try await relayWithdrawal(
            security: Self.relaySecurity(),
            renewed: Self.renewedWithdrawQuote(accountIndex: session.accountIndex)
        )

        let operationId = try await withdrawal.service.pay(
            review: Self.usdcWithdrawReview(accountIndex: session.accountIndex, expiresIn: 5),
            passcode: "1234"
        )

        let sent = await withdrawal.calls.sent
        XCTAssertEqual(sent.count, 1)
        let transfer = try Self.json(XCTUnwrap(sent.first))
        XCTAssertEqual((transfer["ToAccountIndex"] as? NSNumber)?.int64Value, Self.relayAccount)
        XCTAssertEqual((transfer["Amount"] as? NSNumber)?.int64Value, 9_000_000)
        let withdraw = try await withdrawal.journal.funding(operationId: operationId)?.withdraw
        XCTAssertEqual(withdraw?.quoteId, "renewed")
        XCTAssertEqual(withdraw?.stage, .accepted)
        try await withdrawal.journal.removeFunding(operationId: operationId)
    }

    func testASecondWithdrawalFromTheSameReviewSignsARenewedQuote() async throws {
        let withdrawal = try await relayWithdrawal(
            security: Self.relaySecurity(),
            renewed: Self.renewedWithdrawQuote(accountIndex: session.accountIndex)
        )
        let review = Self.usdcWithdrawReview(accountIndex: session.accountIndex)

        let first = try await withdrawal.service.pay(review: review, passcode: "1234")
        let second = try await withdrawal.service.pay(review: review, passcode: "1234")

        let sent = await withdrawal.calls.sent
        XCTAssertEqual(sent.count, 2)
        let quotes = await withdrawal.calls.quotes
        XCTAssertEqual(quotes, 1)
        let firstWithdraw = try await withdrawal.journal.funding(operationId: first)?.withdraw
        let secondWithdraw = try await withdrawal.journal.funding(operationId: second)?.withdraw
        XCTAssertEqual(firstWithdraw?.quoteId, "quote")
        XCTAssertEqual(firstWithdraw?.executionId, "execution")
        XCTAssertEqual(secondWithdraw?.quoteId, "renewed")
        XCTAssertEqual(secondWithdraw?.executionId, "renewed-execution")
        try await withdrawal.journal.removeFunding(operationId: first)
        try await withdrawal.journal.removeFunding(operationId: second)
    }

    func testATradeFromAFormOpenedBeforeRecoveryResentAStepSignsAfterThatStep() async throws {
        let vault = InMemoryKeychainVault()
        let wallet = makeWallet(id: UUID().uuidString)
        let store = credentials(vault, wallet)
        try store.saveL2PrivateKey(Data(repeating: 0xAB, count: 40))
        try store.saveAccount(PerpsStoredAccount(accountIndex: session.accountIndex, apiKeyIndex: session.apiKeyIndex, keyDerivationIndex: 0))
        try store.saveIntegratorApproval(
            PerpsIntegratorApproval(key: approvalKey(), expiry: PerpsPlannerMapping.nowUnixMs() + 30 * 86_400_000)
        )
        let journal = makeJournal(wallet)
        let unsentId = UUID().uuidString
        _ = try await journal.savePendingIfAbsentWithStatus(PerpsPendingTradingAction(
            operationId: unsentId, walletId: wallet.id, marketId: 2, side: .long,
            payload: .open(limitPrice: nil),
            orderRefs: [.init(role: .parent, clientOrderIndex: 77)],
            signedSteps: [PerpsPendingSignedStep(
                stepId: "open", attemptId: UUID().uuidString, nonce: 287,
                transactionExpiryUnixMs: PerpsPlannerMapping.nowUnixMs() + 600_000,
                txType: 14, txInfo: "{\"Nonce\":287}", txHash: "0xabc", state: .signed
            )]
        ))
        let venue = NonceVenue(next: 287)
        let api = AccountStubAPI(
            account: .init(),
            onAccountTier: { .init(id: "1", name: "plus") },
            integrator: .tonkeeper,
            onNextNonce: { await venue.next },
            tradingScreen: Self.tradingScreen(),
            orderBook: Self.orderBook(),
            onSendTransactions: { _, transactions in
                try await venue.accept(transactions[0], journaledIn: journal)
            }
        )
        let trading = makeTrading(makeService(api: api, vault: vault), wallet: wallet, api: api)
        let prepared = try await trading.prepareOpen(.init(
            marketId: 1, side: .long, marginUsd: "100", leverage: 10, maxSlippage: 0.01, autoClose: nil
        ))

        _ = await trading.openMarketContext(marketId: 1, side: .long)
        try await Task.sleep(nanoseconds: 200_000_000)
        let result = await trading.submit(prepared, passcodeProvider: { nil })

        guard case let .submitted(trade) = result else { return XCTFail("the trade must be accepted: \(result)") }
        let sentNonces = await venue.sent
        XCTAssertEqual(sentNonces, [287, 288, 289])
        XCTAssertEqual(trade.signedSteps?.map(\.nonce), [288, 289])
        try await journal.removePending(operationId: prepared.operationId)
        try await journal.removePending(operationId: unsentId)
    }

    func testTheApprovalCarriesTheOwnerSignatureAndIsRecorded() async throws {
        let vault = InMemoryKeychainVault()
        let wallet = makeWallet()
        let mnemonicAccess = makeMnemonicAccess(vault: vault)
        try await mnemonicAccess.saveMnemonic(
            CoreMnemonic(mnemonicWords: Self.mnemonic.components(separatedBy: " "), type: .bip39),
            wallet: wallet,
            passcode: "1234"
        )
        let store = credentials(vault, wallet)
        try await store.keepTradingKey(cryptoWallet: CryptoWallet.Companion.shared.fromMnemonic(mnemonic_: Self.mnemonic))
        let privateKeyHex = try XCTUnwrap(store.loadL2PrivateKey()).map { String(format: "%02x", $0) }.joined()
        let sent = SentApprovals()
        let api = AccountStubAPI(
            account: .init(),
            integrator: .tonkeeper,
            nonce: 287,
            onSendTransactions: { _, transactions in
                await sent.record(transactions)
                let hash = try await Self.transactionHash(transactions[0], privateKeyHex: privateKeyHex)
                return .init(transactions: [.init(tx_type: transactions[0].tx_type, tx_hash: hash)])
            }
        )
        let service = makeService(api: api, vault: vault, mnemonicAccess: mnemonicAccess)
        let lane = await service.submitLanes.lane(for: session)
        // An order Lighter refused has already taken 287 without using it.
        _ = try await lane.nextNonce(walletId: wallet.id)

        let prepared = try await service.prepareIntegratorApproval(
            wallet: wallet,
            session: session,
            passcodeProvider: { "1234" }
        )
        let approval = try XCTUnwrap(prepared)
        try await lane.run {
            try await service.submitIntegratorApproval(approval, wallet: wallet, session: session, lane: lane)
        }

        let transactions = await sent.transactions
        XCTAssertEqual(transactions.map(\.tx_type), [Int32(LighterConstants.shared.TxTypeL2ApproveIntegrator)])
        let txInfo = try Self.json(transactions[0].tx_info)
        XCTAssertEqual((txInfo["Nonce"] as? NSNumber)?.int64Value, 287)
        let l1Signature = try XCTUnwrap(txInfo["L1Sig"] as? String)
        XCTAssertTrue(l1Signature.hasPrefix("0x"))
        XCTAssertEqual(l1Signature.count, 132)
        let recorded = try XCTUnwrap(store.loadIntegratorApproval())
        XCTAssertEqual(recorded.key, approvalKey())
        XCTAssertEqual(recorded.expiry, (txInfo["ApprovalExpiry"] as? NSNumber)?.int64Value)
    }
}

private extension PerpsIntegratorApprovalTests {
    static let mnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
    static let ethAddress = "0x9858effd232b4033e47d90003d41ec34ecaeda94"

    static func tradingScreen() -> Components.Schemas.TradingScreen {
        .init(
            market: .init(
                market_index: 1, symbol: "ETH", quote_asset: "USDC", status: "active",
                price_decimals: 2, size_decimals: 4, tick_size: "0.01", step_size: "0.0001", min_size_base: "0.001", min_size_quote: "10", max_leverage: 25,
                maker_fee_pct: "0.02", taker_fee_pct: "0.04", initial_margin_fraction: 400,
                maintenance_margin_fraction: 300, mark_price: "2000"
            ),
            open_orders: [],
            balance: .init(available_balance: "1000"),
            flags: .init(open_enabled: true, cancel_enabled: true)
        )
    }

    static func orderBook() -> Components.Schemas.TruncatedOrderBook {
        .init(
            updated_at: Date(), truncated: true,
            bids: [.init(price: "1999", size: "10")], asks: [.init(price: "2000", size: "10")]
        )
    }

    func approvalKey(maxPerpsTakerFee: Int = 1000) -> PerpsIntegratorApprovalKey {
        PerpsIntegratorApprovalKey(
            accountIndex: session.accountIndex,
            integratorAccountIndex: Components.Schemas.Integrator.tonkeeper.integrator_account_index,
            maxPerpsTakerFee: maxPerpsTakerFee,
            maxPerpsMakerFee: 1000,
            maxSpotTakerFee: 0,
            maxSpotMakerFee: 0
        )
    }

    func credentials(_ vault: InMemoryKeychainVault, _ wallet: Wallet) -> LighterCredentialsStore {
        LighterCredentialsStore(keychainVault: vault, walletId: wallet.id, environment: PerpsEnvironment.storage)
    }

    func makeMnemonicAccess(vault: InMemoryKeychainVault) -> MnemonicAccess {
        .inMemory(seed: "integrator-approval", keychainVault: vault)
    }

    func savedMnemonicAccess(vault: InMemoryKeychainVault, wallet: Wallet) async throws -> MnemonicAccess {
        let access = makeMnemonicAccess(vault: vault)
        try await access.saveMnemonic(
            CoreMnemonic(mnemonicWords: Self.mnemonic.components(separatedBy: " "), type: .bip39),
            wallet: wallet,
            passcode: "1234"
        )
        return access
    }

    static let relayAccount: Int64 = 731_033
    static let otherRelayAccount: Int64 = 731_034

    static func relaySecurity(_ accounts: Set<Int64> = [relayAccount]) -> PerpsSecurityConfig {
        var security = KeyRegistrationFixture.security
        security.relayLighterAccounts = accounts
        return security
    }

    static func renewedWithdrawQuote(
        accountIndex: Int64,
        toAccountIndex: Int64 = relayAccount,
        amount: String = "9000000",
        feeUnits: String = "0"
    ) -> Components.Schemas.WithdrawQuote {
        let now = Date()
        return .init(
            quote_id: "renewed",
            provider: "relay",
            created_at: now,
            expires_at: now.addingTimeInterval(60),
            input: .init(asset_id: PerpsFundingAssetId.usdcEthereum, amount: "10000000", account_index: accountIndex),
            output: .init(asset_id: PerpsFundingAssetId.usdcEthereum, amount: "9950000", min_amount: "9900000", address: ethAddress),
            operation: .transfer(id: "operation", [
                .payload("main", chain: "lighter/mainnet", meta: Components.Schemas.PayloadMetaLighterTransfer(
                    to_account_index: toAccountIndex,
                    asset_index: 3,
                    from_route_type: 0,
                    to_route_type: 0,
                    amount: amount,
                    usdc_fee: feeUnits,
                    memo: "0x" + String(repeating: "c", count: 64)
                )),
            ]),
            tracking: .init(execution_id: "renewed-execution", status_url: "/funding/status/renewed-execution")
        )
    }

    func relayWithdrawal(
        security: PerpsSecurityConfig?,
        renewed: Components.Schemas.WithdrawQuote? = nil
    ) async throws -> (service: PerpsWithdrawService, journal: PerpsPendingJournal, calls: WithdrawalCalls) {
        let vault = InMemoryKeychainVault()
        let wallet = makeWallet(id: UUID().uuidString)
        let store = credentials(vault, wallet)
        try store.saveL2PrivateKey(Data(repeating: 0xAB, count: 40))
        try store.saveAccount(PerpsStoredAccount(accountIndex: session.accountIndex, apiKeyIndex: session.apiKeyIndex, keyDerivationIndex: 0))
        let mnemonicAccess = try await savedMnemonicAccess(vault: vault, wallet: wallet)
        let journal = makeJournal(wallet)
        let calls = WithdrawalCalls()
        let api = AccountStubAPI(
            account: .init(account_index: Int(session.accountIndex), l1_address: Self.ethAddress),
            balance: .init(available_balance: "1000"),
            nonce: 289,
            onSendTransactions: { _, transactions in
                try await calls.send(transactions[0], journaledIn: journal)
            },
            onQuoteWithdraw: { _ in
                try await calls.quote(renewed)
            }
        )
        let service = makeService(api: api, vault: vault, mnemonicAccess: mnemonicAccess)
        let withdrawals = try XCTUnwrap(service.withdrawService(
            wallet: wallet,
            journal: journal,
            recovery: service.fundingRecovery(wallet: wallet, journal: journal),
            readOnlyToken: makeReadOnlyToken(service, wallet),
            transferFeeUnits: { _, _ in nil },
            securityConfig: { security }
        ))
        return (withdrawals, journal, calls)
    }

    static func usdcWithdrawReview(accountIndex: Int64, expiresIn: TimeInterval = 60, transferUnits: Int64 = 10_000_000) -> PerpsWithdrawReview {
        let quote = PerpsWithdrawQuote(
            quoteId: "quote",
            expiresAt: Date().addingTimeInterval(expiresIn),
            executionId: "execution",
            destinationAssetId: PerpsFundingAssetId.usdcEthereum,
            recipient: ethAddress,
            budgetUnits: "10000000",
            outputUnits: "9950000",
            minimumOutputUnits: "9900000",
            toAccountIndex: 731_033,
            transferUnits: transferUnits,
            feeUnits: 0,
            memo: Data(repeating: 0xAB, count: 32)
        )
        return PerpsWithdrawReview(
            destination: PerpsFundingAsset(assetId: PerpsFundingAssetId.usdcEthereum, symbol: "USDC", decimals: 6),
            amount: "10", receiveAmount: "9.9", networkFee: "0", expiresAt: quote.expiresAt, estimatedDurationSeconds: nil,
            amountUnits: "10000000", accountIndex: accountIndex, recipient: ethAddress, quote: quote
        )
    }

    func makeService(
        api: PerpsAPI,
        vault: InMemoryKeychainVault = InMemoryKeychainVault(),
        mnemonicAccess: MnemonicAccess? = nil
    ) -> PerpsAccountService {
        let client = CryptoKitClient(netModule: ModuleNetModule(netConfig: ModuleNetConfig(
            isLogging: false, logger: nil, userAgent: nil, sessionProvider: nil, nodeManifestHost: nil
        )))
        return PerpsAccountService(
            mnemonicAccess: mnemonicAccess ?? makeMnemonicAccess(vault: vault),
            keychainVault: vault,
            perpsAPI: api,
            submitLanes: PerpsSubmitLanes(api: api),
            bindSigner: PerpsAccountBindSigner(client: client),
            walletAuthTokenProvider: ApprovalUnusedWalletAuth(),
            chainKitClient: client,
            depositGate: OperationGate { [] },
            tierUpgrader: PerpsAccountTierUpgrader(retryDelayNanoseconds: 0)
        )
    }

    func makeJournal(_ wallet: Wallet) -> PerpsPendingJournal {
        PerpsPendingJournal(walletId: wallet.id, environment: PerpsEnvironment.storage)
    }

    func makeReadOnlyToken(_ service: PerpsAccountService, _ wallet: Wallet) -> PerpsReadOnlyToken {
        PerpsReadOnlyToken(mint: { await service.mintReadOnlyToken(wallet: wallet) })
    }

    func makeTrading(
        _ service: PerpsAccountService,
        wallet: Wallet,
        api: PerpsAPI,
        tradingScreenReads: PerpsTradingScreenReads = PerpsTradingScreenReads(),
        operationJournaled: @escaping @Sendable () -> Void = {},
        trades: TradeEvents = TradeEvents(),
        securityConfig: @escaping @Sendable () async -> PerpsSecurityConfig? = { .listing(.matching(PerpsIntegratorApprovalTests.tradingScreen().market ?? .init())) }
    ) -> PerpsTkTradingService {
        PerpsTkTradingService(
            accountService: service,
            wallet: wallet,
            journal: makeJournal(wallet),
            readOnlyToken: makeReadOnlyToken(service, wallet),
            perpsAPI: api,
            markPriceProvider: { _ in nil },
            marketProvider: { _ in nil },
            tradingScreenReads: tradingScreenReads,
            operationJournaled: operationJournaled,
            tradeBegan: { trades.record(.began($0, marketId: $1, $2)) },
            tradeSettled: { trades.record(.settled($0, succeeded: $1)) },
            positionClosed: { operationId, _ in trades.record(.closed(operationId)) },
            securityConfig: securityConfig,
            freshReadDelayNanoseconds: 0
        )
    }

    func makeWallet(id: String = "perps-integrator-approval", multichainId: String? = nil) -> Wallet {
        Wallet(
            id: id,
            identity: WalletIdentity(network: .mainnet, kind: .Regular(TonSwift.PublicKey(data: Data(repeating: 1, count: 32)), .v4R2)),
            metaData: WalletMetaData(label: "Perps", tintColor: .defaultColor, icon: .icon(.wallet)),
            setupSettings: WalletSetupSettings(isSetupFinished: true),
            batterySettings: BatterySettings(),
            multichain: .multichain(MultichainWalletState(
                walletId: multichainId ?? id,
                addresses: [.init(chain: .eth, address: Self.ethAddress)],
                syncState: .synced
            ))
        )
    }

    static func json(_ text: String) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
    }

    static func transactionHash(_ signed: Components.Schemas.SignedTransaction, privateKeyHex: String) async throws -> String {
        let fields = try json(signed.tx_info)
        func int64(_ name: String) throws -> Int64 {
            try XCTUnwrap((fields[name] as? NSNumber)?.int64Value)
        }
        let client = try LighterClient(
            crypto: LighterCryptoBridge(crypto: CoreLighterCrypto()),
            nowMillis: { KotlinLong(value: 0) }
        ).doNewTxClient(
            privateKeyHex: privateKeyHex,
            accountIndex: int64("AccountIndex"),
            apiKeyIndex: Int32(int64("ApiKeyIndex")),
            chainId: LighterConstants.shared.ChainId
        )
        let options = try LighterTransactOpts(
            fromAccountIndex: nil,
            apiKeyIndex: nil,
            expiredAt: int64("ExpiredAt"),
            nonce: KotlinLong(value: int64("Nonce")),
            attributes: nil,
            dryRun: false
        )
        if signed.tx_type == LighterConstants.shared.TxTypeL2UpdateLeverage {
            let request = try LighterUpdateLeverageTxReq(
                marketIndex: Int16(int64("MarketIndex")),
                initialMarginFraction: Int32(int64("InitialMarginFraction")),
                marginMode: Int32(int64("MarginMode"))
            )
            let transaction: L2UpdateLeverageTxInfo = try await bridgeKotlin { completion in
                client.getUpdateLeverageTransaction(req: request, ops: options, completionHandler: completion)
            }
            return transaction.getTxHash()
        }
        let request = try LighterApproveIntegratorTxReq(
            integratorAccountIndex: int64("IntegratorAccountIndex"),
            maxPerpsTakerFee: Int32(int64("MaxPerpsTakerFee")),
            maxPerpsMakerFee: Int32(int64("MaxPerpsMakerFee")),
            maxSpotTakerFee: Int32(int64("MaxSpotTakerFee")),
            maxSpotMakerFee: Int32(int64("MaxSpotMakerFee")),
            approvalExpiry: int64("ApprovalExpiry")
        )
        let transaction: L2ApproveIntegratorTxInfo = try await bridgeKotlin { completion in
            client.getApproveIntegratorTransaction(req: request, ops: options, l1Signer: nil, completionHandler: completion)
        }
        return transaction.getTxHash()
    }
}

private extension Components.Schemas.Integrator {
    static var tonkeeper: Self {
        tonkeeper(approvalTtlMs: 31_536_000_000)
    }

    static func tonkeeper(approvalTtlMs: Int64) -> Self {
        .init(
            integrator_account_index: 281_474_976_487_764,
            integrator_taker_fee: 900,
            integrator_maker_fee: 900,
            max_perps_taker_fee: 1000,
            max_perps_maker_fee: 1000,
            max_spot_taker_fee: 0,
            max_spot_maker_fee: 0,
            approval_ttl_ms: approvalTtlMs
        )
    }
}

private actor PromptCount {
    private(set) var count = 0

    func cancel() -> String? {
        count += 1
        return nil
    }
}

private actor SentApprovals {
    private(set) var transactions: [Components.Schemas.SignedTransaction] = []

    func record(_ sent: [Components.Schemas.SignedTransaction]) {
        transactions.append(contentsOf: sent)
    }
}

private actor SecurityConfigReads {
    private(set) var count = 0

    func read(_ config: PerpsSecurityConfig) -> PerpsSecurityConfig {
        count += 1
        return config
    }
}

private actor LaneSends {
    private let firstSendHeld: AsyncStream<Void>
    private let firstSendArrived: XCTestExpectation
    private(set) var nonces = [Int64]()
    private(set) var overlapped = false
    private var inFlight = 0

    init(holdingFirstSendUntil released: AsyncStream<Void>, announcing arrived: XCTestExpectation) {
        firstSendHeld = released
        firstSendArrived = arrived
    }

    func accept(
        _ transaction: Components.Schemas.SignedTransaction,
        journaledIn journal: PerpsPendingJournal
    ) async throws -> Components.Schemas.SendTransactionsResponse {
        inFlight += 1
        overlapped = overlapped || inFlight > 1
        defer { inFlight -= 1 }
        try nonces.append(XCTUnwrap((PerpsIntegratorApprovalTests.json(transaction.tx_info)["Nonce"] as? NSNumber)?.int64Value))
        if nonces.count == 1 {
            firstSendArrived.fulfill()
            for await _ in firstSendHeld {}
        }
        let trading = try await journal.allPending().flatMap { $0.signedSteps ?? [] }
        let funding = try await journal.allFunding().compactMap(\.withdraw).flatMap(\.steps)
        let hash = (trading + funding).first { $0.txInfo == transaction.tx_info }?.txHash ?? ""
        return .init(transactions: [.init(tx_type: transaction.tx_type, tx_hash: hash)])
    }
}

private actor MovingNonce {
    /// `nil` makes the read fail.
    private(set) var value: Int64?

    init(_ value: Int64) {
        self.value = value
    }

    func move(to value: Int64?) {
        self.value = value
    }

    func read() throws -> Int64 {
        guard let value else { throw AccountStubAPI.Unsupported() }
        return value
    }
}

private actor WithdrawalCalls {
    private(set) var quotes = 0
    private(set) var sent = [String]()

    func quote(_ renewed: Components.Schemas.WithdrawQuote?) throws -> Components.Schemas.WithdrawQuote {
        quotes += 1
        guard let renewed else { throw AccountStubAPI.Unsupported() }
        return renewed
    }

    func send(
        _ transaction: Components.Schemas.SignedTransaction,
        journaledIn journal: PerpsPendingJournal
    ) async throws -> Components.Schemas.SendTransactionsResponse {
        sent.append(transaction.tx_info)
        let steps = try await journal.allFunding().compactMap(\.withdraw).flatMap(\.steps)
        let hash = steps.first { $0.txInfo == transaction.tx_info }?.txHash ?? ""
        return .init(transactions: [.init(tx_type: transaction.tx_type, tx_hash: hash)])
    }
}

private actor NonceVenue {
    private(set) var next: Int64
    private(set) var sent = [Int64]()

    init(next: Int64) {
        self.next = next
    }

    func accept(
        _ transaction: Components.Schemas.SignedTransaction,
        journaledIn journal: PerpsPendingJournal
    ) async throws -> Components.Schemas.SendTransactionsResponse {
        let nonce = try XCTUnwrap((PerpsIntegratorApprovalTests.json(transaction.tx_info)["Nonce"] as? NSNumber)?.int64Value)
        guard nonce == next else {
            throw PerpsAPIError.badStatus(
                PerpsAPIFailure(httpStatus: 400, code: "validation_error", message: nil, retryable: false, reason: "resign_required")
            )
        }
        next += 1
        sent.append(nonce)
        let hash = try await journal.allPending().flatMap { $0.signedSteps ?? [] }.first { $0.txInfo == transaction.tx_info }?.txHash ?? ""
        return .init(transactions: [.init(tx_type: transaction.tx_type, tx_hash: hash)])
    }
}

private actor JournaledStates {
    private(set) var states: [[PerpsPendingStepState]?] = []

    func record(_ journaled: [PerpsPendingStepState]?) {
        states.append(journaled)
    }
}

private struct ApprovalUnusedWalletAuth: WalletAuthTokenProviding {
    func token(walletId _: String, accessToken _: String) async -> String? {
        nil
    }

    func invalidateToken(walletId _: String) async {}
    func hasPersistentAppKey(walletId _: String) async -> Bool {
        false
    }

    func warm(walletId _: String, mnemonic _: String) async {}
    func persistAppKey(_: Data, walletId _: String) async {}
    func forget(walletId _: String) async {}
    func wipe() async {}
}

private final class TradeEvents: @unchecked Sendable {
    enum Event: Equatable {
        case began(String, marketId: Int64, PerpsTradeInProgress)
        case settled(String, succeeded: Bool)
        case closed(String)
    }

    private let lock = NSLock()
    private var recorded: [Event] = []

    var events: [Event] {
        lock.withLock { recorded }
    }

    func record(_ event: Event) {
        lock.withLock { recorded.append(event) }
    }
}

extension PerpsIntegratorApprovalTests {
    func testAutoCloseRebaseIsJournaledWithTheEntryBeforeSendingAndKeepsFixedPriceLegs() async throws {
        let (wallet, vault) = try rebaseWallet()
        let journal = makeJournal(wallet)
        let sent = SentApprovals()
        let privateKeyHex = Data(repeating: 0xAB, count: 40).map { String(format: "%02x", $0) }.joined()
        let api = AccountStubAPI(
            account: .init(), nonce: 287, tradingScreen: Self.tradingScreen(), orderBook: Self.orderBook(),
            onSendTransactions: { _, transactions in
                if transactions[0].tx_type == LighterConstants.shared.TxTypeL2UpdateLeverage {
                    let hash = try await Self.transactionHash(transactions[0], privateKeyHex: privateKeyHex)
                    return .init(transactions: [.init(tx_type: transactions[0].tx_type, tx_hash: hash)])
                }
                let pending = try await journal.allPending()
                let corrections = pending.filter { if case .autoCloseRebase = $0.payload { return true }; return false }
                XCTAssertEqual(pending.count, 2)
                XCTAssertEqual(corrections.count, 1, "a fixed-price SL must have no correction")
                XCTAssertEqual(corrections.first?.triggerOrderRefs.first?.role, .takeProfit)
                await sent.record(transactions)
                throw PerpsAPIError.transport(underlying: URLError(.timedOut))
            }
        )
        let trading = makeTrading(makeService(api: api, vault: vault), wallet: wallet, api: api)
        let prepared = try await trading.prepareOpen(.init(
            marketId: 1, side: .long, marginUsd: "100", leverage: 10, maxSlippage: 0.01,
            autoClose: .init(takeProfit: .init(triggerPrice: 2100), stopLoss: .init(triggerPrice: 1970)),
            takeProfitROIPercent: 20
        ))
        _ = await trading.submit(prepared, passcodeProvider: { nil })
        let sends = await sent.transactions
        XCTAssertEqual(sends.count, 1)
        let all = try await journal.allPending()
        XCTAssertEqual(all.count, 2)
        for pending in all {
            try await journal.removePending(operationId: pending.operationId)
        }
    }

    func testAutoCloseRebaseIsJournaledWithAnAddAndRemembersThePositionBefore() async throws {
        let (wallet, vault) = try rebaseWallet()
        let journal = makeJournal(wallet)
        let sent = SentApprovals()
        var screen = Self.tradingScreen()
        screen.position = .init(value1: .init(
            market_index: 1, symbol: "ETH", side: .long, size: "1", avg_entry_price: "2000",
            liquidation_price: "1700", margin_mode: .isolated, allocated_margin: "200", leverage: 10
        ))
        let api = AccountStubAPI(
            account: .init(), nonce: 287, tradingScreen: screen, orderBook: Self.orderBook(),
            onSendTransactions: { _, transactions in
                let corrections = try await journal.allPending().compactMap { pending -> PerpsPendingAutoCloseRebase? in
                    guard case let .autoCloseRebase(rebase) = pending.payload else { return nil }
                    return rebase
                }
                XCTAssertEqual(corrections.count, 1)
                XCTAssertEqual(corrections.first?.positionBaseBefore, 1)
                XCTAssertEqual(corrections.first?.leverage, 10)
                XCTAssertEqual(corrections.first?.roiPercent, 20)
                await sent.record(transactions)
                throw PerpsAPIError.transport(underlying: URLError(.timedOut))
            }
        )
        let trading = makeTrading(makeService(api: api, vault: vault), wallet: wallet, api: api)
        let prepared = try await trading.prepareSizeChange(.init(
            marketId: 1, direction: .add, marginDeltaUsd: "50",
            autoCloseUpdate: .replace(.init(takeProfit: .init(triggerPrice: 2100), stopLoss: nil)),
            takeProfitROIPercent: 20
        )).get()
        _ = await trading.submit(prepared, passcodeProvider: { nil })
        let sends = await sent.transactions
        XCTAssertEqual(sends.count, 1)
        let all = try await journal.allPending()
        XCTAssertEqual(all.count, 2)
        for pending in all {
            try await journal.removePending(operationId: pending.operationId)
        }
    }

    func testAReduceWithinACentOfTheMarginClosesTheWholePosition() async throws {
        let (wallet, vault) = try rebaseWallet()
        var screen = Self.tradingScreen()
        screen.position = .init(value1: .init(
            market_index: 1, symbol: "ETH", side: .long, size: "1", avg_entry_price: "2000",
            liquidation_price: "1700", margin_mode: .isolated, allocated_margin: "200.0043", leverage: 10
        ))
        let api = AccountStubAPI(account: .init(), nonce: 287, tradingScreen: screen, orderBook: Self.orderBook())
        let trading = makeTrading(makeService(api: api, vault: vault), wallet: wallet, api: api)

        let whole = try await trading.prepareSizeChange(.init(
            marketId: 1, direction: .reduce, marginDeltaUsd: "200"
        )).get()
        XCTAssertEqual(whole.review.baseSize.new, 0)
        XCTAssertTrue(whole.review.closesWholePosition)

        let partial = try await trading.prepareSizeChange(.init(
            marketId: 1, direction: .reduce, marginDeltaUsd: "199.99"
        )).get()
        XCTAssertEqual(partial.review.baseSize.new, 0.0001, accuracy: 1e-9)
        XCTAssertFalse(partial.review.closesWholePosition)
    }

    func testASubmitRefusesAReduceWhoseWholeCloseDecisionMovedWithTheMargin() async throws {
        let (wallet, vault) = try rebaseWallet()
        let sent = SentApprovals()
        func trading(margin: String) -> PerpsTkTradingService {
            var screen = Self.tradingScreen()
            screen.position = .init(value1: .init(
                market_index: 1, symbol: "ETH", side: .long, size: "1", avg_entry_price: "2000",
                liquidation_price: "1700", margin_mode: .isolated, allocated_margin: margin, leverage: 10
            ))
            let api = AccountStubAPI(
                account: .init(), nonce: 287, tradingScreen: screen, orderBook: Self.orderBook(),
                onSendTransactions: { _, transactions in
                    await sent.record(transactions)
                    throw PerpsAPIError.transport(underlying: URLError(.timedOut))
                }
            )
            return makeTrading(makeService(api: api, vault: vault), wallet: wallet, api: api)
        }

        for (input, preparedMargin, submittedMargin) in [("200", "200.0043", "200.02"), ("199.99", "200.0043", "199.995")] {
            let prepared = try await trading(margin: preparedMargin).prepareSizeChange(.init(
                marketId: 1, direction: .reduce, marginDeltaUsd: input
            )).get()
            let result = await trading(margin: submittedMargin).submit(prepared, passcodeProvider: { nil })
            guard case .failed(.stalePreparedTransaction) = result else {
                return XCTFail("a whole-close decision that moved must refuse the submit, got \(result)")
            }
        }
        let sends = await sent.transactions
        XCTAssertTrue(sends.isEmpty)
    }

    func testAutoCloseRebaseSendsAModifyAndNeverResignsAfterAnAmbiguousSend() async throws {
        let (wallet, vault) = try rebaseWallet()
        let journal = makeJournal(wallet)
        let pending = rebasePending(wallet)
        _ = try await journal.savePendingIfAbsentWithStatus(pending)
        let sent = SentApprovals()
        let api = rebaseAPI(sent: sent)
        let trading = makeTrading(makeService(api: api, vault: vault), wallet: wallet, api: api)

        _ = await trading.recoverInterruptedOperations()
        _ = await trading.recoverInterruptedOperations()

        let sends = await sent.transactions
        XCTAssertEqual(sends.count, 1)
        let tx = try XCTUnwrap(sends.first)
        XCTAssertEqual(tx.tx_type, LighterConstants.shared.TxTypeL2ModifyOrder)
        let body = try Self.json(tx.tx_info)
        XCTAssertEqual((body["Index"] as? NSNumber)?.int64Value, 777)
        XCTAssertEqual((body["BaseAmount"] as? NSNumber)?.int64Value, LighterConstants.shared.NilOrderBaseAmount)
        XCTAssertEqual((body["TriggerPrice"] as? NSNumber)?.int64Value, 204_000)
        let record = try await journal.pending(operationId: pending.operationId)
        let stored = try XCTUnwrap(record)
        XCTAssertEqual(stored.signedSteps?.count, 1)
        XCTAssertEqual(stored.signedSteps?.first?.state, .unknown)
        guard case let .autoCloseRebase(rebase) = stored.payload else { return XCTFail("lost correction") }
        XCTAssertEqual(rebase.targetPrice, 2040)

        let confirmedAPI = rebaseAPI(trigger: "2040", sent: sent)
        let relaunched = makeTrading(makeService(api: confirmedAPI, vault: vault), wallet: wallet, api: confirmedAPI)
        let complete = await relaunched.recoverInterruptedOperations()
        let remaining = try await journal.allPending()
        let recorded = try await journal.confirmedAutoClose(marketId: 1)
        XCTAssertTrue(complete)
        XCTAssertTrue(remaining.isEmpty)
        XCTAssertEqual(recorded?.takeProfit?.triggerPrice, 2040, "the renewal may sign the correction it found on the venue")
        let afterConfirmation = await sent.transactions
        XCTAssertEqual(afterConfirmation.count, 1)
    }

    func testAutoCloseRebaseRefusesAmbiguousParentClientIndexes() async throws {
        let (wallet, vault) = try rebaseWallet()
        let journal = makeJournal(wallet)
        let pending = rebasePending(wallet)
        _ = try await journal.savePendingIfAbsentWithStatus(pending)
        let sent = SentApprovals()
        let api = rebaseAPI(parentIndexes: [55, 56], sent: sent)
        let trading = makeTrading(makeService(api: api, vault: vault), wallet: wallet, api: api)
        _ = await trading.recoverInterruptedOperations()
        let sends = await sent.transactions
        let stored = try await journal.pending(operationId: pending.operationId)
        XCTAssertTrue(sends.isEmpty)
        XCTAssertNil(stored)
    }

    func testAutoCloseRebaseKeepsItsCorrectionWhileTheSignedConfigRefusesTheMarket() async throws {
        let (wallet, vault) = try rebaseWallet()
        let journal = makeJournal(wallet)
        let pending = rebasePending(wallet)
        _ = try await journal.savePendingIfAbsentWithStatus(pending)
        let sent = SentApprovals()
        let api = rebaseAPI(sent: sent)
        let served = Self.tradingScreen().market ?? .init()
        XCTAssertNotEqual(served.max_leverage, 10)
        let refusing = PerpsSecurityConfig.listing(.matching(served, maxLeverage: 10))
        let configReads = SecurityConfigReads()
        let trading = makeTrading(
            makeService(api: api, vault: vault), wallet: wallet, api: api,
            securityConfig: { await configReads.read(refusing) }
        )
        _ = await trading.recoverInterruptedOperations()
        let sends = await sent.transactions
        let stored = try await journal.pending(operationId: pending.operationId)
        let reads = await configReads.count
        XCTAssertGreaterThan(reads, 0)
        XCTAssertTrue(sends.isEmpty)
        XCTAssertNotNil(stored)
        try await journal.removePending(operationId: pending.operationId)
    }

    func testAutoCloseRebasePricesFromThePositionAverageEntry() async throws {
        let (wallet, vault) = try rebaseWallet()
        let journal = makeJournal(wallet)
        let pending = rebasePending(wallet)
        _ = try await journal.savePendingIfAbsentWithStatus(pending)
        let sent = SentApprovals()
        let api = rebaseAPI(entry: "2000.01", sent: sent)
        let trading = makeTrading(makeService(api: api, vault: vault), wallet: wallet, api: api)
        _ = await trading.recoverInterruptedOperations()
        let sends = await sent.transactions
        let tx = try XCTUnwrap(sends.first)
        let body = try Self.json(tx.tx_info)
        XCTAssertEqual((body["TriggerPrice"] as? NSNumber)?.int64Value, 204_001)
        try await journal.removePending(operationId: pending.operationId)
    }

    func testAutoCloseRebaseWaitsForItsEntryOperationToSettle() async throws {
        let (wallet, vault) = try rebaseWallet()
        let journal = makeJournal(wallet)
        let pending = rebasePending(wallet)
        // Another wallet's record: recovery leaves it unsettled, so the entry stays in flight.
        let entry = PerpsPendingTradingAction(
            operationId: "open", walletId: "other", marketId: 1, side: .long,
            payload: .open(limitPrice: nil), expiresAtMillis: PerpsPlannerMapping.nowUnixMs() + 86_400_000
        )
        _ = try await journal.savePendingIfAbsentWithStatus(entry)
        _ = try await journal.savePendingIfAbsentWithStatus(pending)
        let sent = SentApprovals()
        let api = rebaseAPI(sent: sent)
        let trading = makeTrading(makeService(api: api, vault: vault), wallet: wallet, api: api)
        _ = await trading.recoverInterruptedOperations()
        let sends = await sent.transactions
        let stored = try await journal.pending(operationId: pending.operationId)
        XCTAssertTrue(sends.isEmpty)
        XCTAssertNotNil(stored)
        try await journal.removePending(operationId: entry.operationId, includingFollowUps: true)
    }

    func testAutoCloseRebaseRecoveredWithItsEntryInOnePassWaitsFromTheSettle() async throws {
        let stale = PerpsPlannerMapping.nowUnixMs() - PerpsAutoCloseRebase.settleWindowMillis - 1
        // A pass walks the journal in dictionary order: varied ids bring the entry up first too.
        for attempt in 0 ..< 8 {
            let (wallet, vault) = try rebaseWallet()
            let journal = makeJournal(wallet)
            let entry = PerpsPendingTradingAction(
                operationId: "open-\(attempt)", createdAtMillis: stale, walletId: wallet.id, marketId: 1, side: .long,
                payload: .open(limitPrice: nil), expectedBaseSize: 1,
                orderRefs: [.init(role: .parent, clientOrderIndex: 123)]
            )
            let pending = rebasePending(wallet, createdAtMillis: stale, parentOperationId: entry.operationId)
            _ = try await journal.savePendingIfAbsentWithStatus(entry)
            _ = try await journal.savePendingIfAbsentWithStatus(pending)
            let sent = SentApprovals()
            let api = rebaseAPI(size: "2", sent: sent)
            let trading = makeTrading(makeService(api: api, vault: vault), wallet: wallet, api: api)

            _ = await trading.recoverInterruptedOperations()

            let settled = try await journal.pending(operationId: entry.operationId)
            let stored = try await journal.pending(operationId: pending.operationId)
            XCTAssertNil(settled, "attempt \(attempt)")
            XCTAssertNotNil(stored, "a correction whose entry just settled still waits for the venue, attempt \(attempt)")
            try await journal.removePending(operationId: pending.operationId)
        }
    }

    func testAutoCloseRebaseAfterAnAddPricesFromTheMergedPosition() async throws {
        for (size, expectedSends) in [("1.5", 1), ("0.5", 0)] {
            let (wallet, vault) = try rebaseWallet()
            let journal = makeJournal(wallet)
            let pending = rebasePending(wallet, positionBaseBefore: 1)
            _ = try await journal.savePendingIfAbsentWithStatus(pending)
            let sent = SentApprovals()
            let api = rebaseAPI(filled: "0.5", size: size, entry: "2010", sent: sent)
            let trading = makeTrading(makeService(api: api, vault: vault), wallet: wallet, api: api)
            _ = await trading.recoverInterruptedOperations()
            let sends = await sent.transactions
            XCTAssertEqual(sends.count, expectedSends, "position size \(size)")
            if let tx = sends.first {
                let body = try Self.json(tx.tx_info)
                XCTAssertEqual((body["TriggerPrice"] as? NSNumber)?.int64Value, 205_020)
            }
            try await journal.removePending(operationId: pending.operationId)
        }
    }

    func testAutoCloseRebaseFindsTheLegInThePositionWhenOrdersAreUnreadable() async throws {
        let (wallet, vault) = try rebaseWallet()
        let journal = makeJournal(wallet)
        let pending = rebasePending(wallet)
        _ = try await journal.savePendingIfAbsentWithStatus(pending)
        let sent = SentApprovals()
        let api = rebaseAPI(ordersReadable: false, sent: sent)
        let trading = makeTrading(makeService(api: api, vault: vault), wallet: wallet, api: api)
        _ = await trading.recoverInterruptedOperations()
        let sends = await sent.transactions
        let tx = try XCTUnwrap(sends.first, "a position leg reports the size it closes, not zero")
        let body = try Self.json(tx.tx_info)
        XCTAssertEqual((body["TriggerPrice"] as? NSNumber)?.int64Value, 204_000)
        try await journal.removePending(operationId: pending.operationId)
    }

    func testAutoCloseRebaseReplaysOnlyAnUnsentPayloadAndOnlyOnce() async throws {
        let (wallet, vault) = try rebaseWallet()
        let journal = makeJournal(wallet)
        let pending = rebasePending(wallet)
        _ = try await journal.savePendingIfAbsentWithStatus(pending)
        try await journal.setRebaseTarget(operationId: pending.operationId, price: 2040)
        try await journal.appendSignedStep(
            operationId: pending.operationId,
            step: .init(
                stepId: "orderModify", attemptId: "saved", nonce: 99,
                transactionExpiryUnixMs: PerpsPlannerMapping.nowUnixMs() + 60000,
                txType: LighterConstants.shared.TxTypeL2ModifyOrder, txInfo: "exact-signed-payload", txHash: "hash", state: .signed
            ), refs: []
        )
        let sent = SentApprovals()
        let api = rebaseAPI(sent: sent)
        let trading = makeTrading(makeService(api: api, vault: vault), wallet: wallet, api: api)
        _ = await trading.recoverInterruptedOperations()
        _ = await trading.recoverInterruptedOperations()
        let sends = await sent.transactions
        XCTAssertEqual(sends.map(\.tx_info), ["exact-signed-payload"])
        let stored = try await journal.pending(operationId: pending.operationId)
        XCTAssertEqual(stored?.signedSteps?.first?.nonce, 99)
        try await journal.removePending(operationId: pending.operationId)
    }

    func testAutoCloseRebaseUsesAModifyForAShortStopLoss() async throws {
        let (wallet, vault) = try rebaseWallet()
        let journal = makeJournal(wallet)
        let pending = PerpsPendingTradingAction(
            operationId: "rebase", walletId: wallet.id, marketId: 1, side: .short,
            payload: .autoCloseRebase(.init(parentOperationId: "open", parentClientOrderIndex: 123, originalTriggerPrice: 2025, roiPercent: -10, leverage: 10)),
            expiresAtMillis: PerpsPlannerMapping.nowUnixMs() + 86_400_000,
            orderRefs: [.init(role: .stopLoss, clientOrderIndex: 777)]
        )
        _ = try await journal.savePendingIfAbsentWithStatus(pending)
        let sent = SentApprovals()
        let api = rebaseAPI(trigger: "2025", shortStopLoss: true, sent: sent)
        let trading = makeTrading(makeService(api: api, vault: vault), wallet: wallet, api: api)
        _ = await trading.recoverInterruptedOperations()
        let sends = await sent.transactions
        let tx = try XCTUnwrap(sends.first)
        let body = try Self.json(tx.tx_info)
        XCTAssertEqual((body["TriggerPrice"] as? NSNumber)?.int64Value, 202_000)
        XCTAssertEqual((body["Price"] as? NSNumber)?.int64Value, 208_060)
        try await journal.removePending(operationId: pending.operationId)
    }

    func testAutoCloseRebaseWaitsForLaggingStateOnlyWithinTheSettleWindow() async throws {
        let stale = PerpsPlannerMapping.nowUnixMs() - PerpsAutoCloseRebase.settleWindowMillis - 1
        for (status, filled, size, trigger, keptWhileFresh) in [
            ("open", "0", "0", "2050", true),
            ("open", "0.4", "0.4", "2050", true),
            ("filled", "1", "2", "2050", true),
            ("filled", "1", "1", "2200", false),
            ("canceled", "0", "1", "2050", false),
        ] {
            let now = PerpsPlannerMapping.nowUnixMs()
            // The window runs from the entry settling, not from the entry being created.
            let timings: [(Int64, Int64?, Bool)] = [(now, nil, true), (stale, nil, false), (stale, now, true), (stale, stale, false)]
            for (createdAt, settledAt, fresh) in timings {
                let (wallet, vault) = try rebaseWallet()
                let journal = makeJournal(wallet)
                let pending = rebasePending(wallet, createdAtMillis: createdAt, entrySettledAtMillis: settledAt)
                _ = try await journal.savePendingIfAbsentWithStatus(pending)
                let sent = SentApprovals()
                let api = rebaseAPI(status: status, filled: filled, size: size, trigger: trigger, sent: sent)
                let trading = makeTrading(makeService(api: api, vault: vault), wallet: wallet, api: api)

                _ = await trading.recoverInterruptedOperations()

                let sends = await sent.transactions
                let stored = try await journal.pending(operationId: pending.operationId)
                let label = "\(status) filled=\(filled) size=\(size) trigger=\(trigger) fresh=\(fresh)"
                XCTAssertTrue(sends.isEmpty, label)
                XCTAssertEqual(stored != nil, keptWhileFresh && fresh, label)
                try await journal.removePending(operationId: pending.operationId)
            }
        }
    }

    func testAutoCloseRebaseCorrectsATerminalPartialFillButRetainsProtectionIfTheTargetWouldFire() async throws {
        for (filled, size, roi, expectedSends) in [("0.4", "0.4", 20.0, 1), ("1", "1", 0.0, 0)] {
            let (wallet, vault) = try rebaseWallet()
            let journal = makeJournal(wallet)
            let pending = rebasePending(wallet, roi: roi)
            _ = try await journal.savePendingIfAbsentWithStatus(pending)
            let sent = SentApprovals()
            let api = rebaseAPI(status: "canceled", filled: filled, size: size, sent: sent)
            let trading = makeTrading(makeService(api: api, vault: vault), wallet: wallet, api: api)

            _ = await trading.recoverInterruptedOperations()

            let sends = await sent.transactions
            XCTAssertEqual(sends.count, expectedSends)
            try await journal.removePending(operationId: pending.operationId)
        }
    }

    func testAutoCloseRebaseMovesTheConfirmedTriggerOnlyWithinTheTolerance() async throws {
        // 20% ROI at 10x puts the trigger 2% above the entry: 2080.8 is 1.5% past the confirmed 2050, 2111.4 is 3%.
        let cases: [(entry: String, signedTrigger: Int64?)] = [("2040", 208_080), ("2070", nil)]
        for (entry, signedTrigger) in cases {
            let (wallet, vault) = try rebaseWallet()
            let journal = makeJournal(wallet)
            let pending = rebasePending(wallet)
            _ = try await journal.savePendingIfAbsentWithStatus(pending)
            let sent = SentApprovals()
            let api = rebaseAPI(entry: entry, sent: sent)
            let trading = makeTrading(makeService(api: api, vault: vault), wallet: wallet, api: api)

            _ = await trading.recoverInterruptedOperations()

            let sends = await sent.transactions
            if let signedTrigger {
                let tx = try XCTUnwrap(sends.first, "entry \(entry)")
                let body = try Self.json(tx.tx_info)
                XCTAssertEqual((body["TriggerPrice"] as? NSNumber)?.int64Value, signedTrigger, "entry \(entry)")
                try await journal.removePending(operationId: pending.operationId)
            } else {
                XCTAssertTrue(sends.isEmpty, "entry \(entry)")
                let stored = try await journal.pending(operationId: pending.operationId)
                XCTAssertNil(stored, "a trigger moved past the tolerance ends the rebase")
            }
        }
    }

    func testRenewalSignsAgainOnlyTheTriggersThisDeviceSigned() async throws {
        let cases: [(signed: Double?, renews: Bool)] = [(nil, false), (2050, true), (2100, false)]
        for (signed, renews) in cases {
            let (wallet, vault) = try rebaseWallet()
            let journal = makeJournal(wallet)
            if let signed {
                try await journal.confirmAutoClose(marketId: 1) { _ in
                    PerpsAutoClose(takeProfit: .init(triggerPrice: signed), stopLoss: nil)
                }
            }
            let sent = SentApprovals()
            let api = rebaseAPI(sent: sent)
            let trading = makeTrading(makeService(api: api, vault: vault), wallet: wallet, api: api)

            _ = await trading.renewExpiringAutoClose(marketIds: [1])

            let sends = await sent.transactions
            XCTAssertEqual(!sends.isEmpty, renews, "signed here at \(String(describing: signed)), resting at 2050")
            for pending in try await journal.allPending() {
                try await journal.removePending(operationId: pending.operationId, includingFollowUps: true)
            }
        }
    }

    func testATPSLChangeWhoseSendOutcomeWasUnknownIsRecordedOnceTheVenueShowsIt() async throws {
        let (wallet, vault) = try rebaseWallet()
        let journal = makeJournal(wallet)
        let target = PerpsAutoClose(takeProfit: .init(triggerPrice: 2050), stopLoss: nil)
        _ = try await journal.savePendingIfAbsentWithStatus(PerpsPendingTradingAction(
            operationId: "change", walletId: wallet.id, marketId: 1, side: .long,
            payload: .autoCloseChange(.init(target: target, restingOrderIndexes: [])),
            signedSteps: [PerpsPendingSignedStep(
                stepId: "takeProfit", attemptId: "saved", nonce: 287,
                transactionExpiryUnixMs: PerpsPlannerMapping.nowUnixMs() + 600_000,
                txType: 14, txInfo: "{\"Nonce\":287}", txHash: "0xabc", state: .unknown
            )]
        ))
        let api = rebaseAPI(sent: SentApprovals())
        let trading = makeTrading(makeService(api: api, vault: vault), wallet: wallet, api: api)

        _ = await trading.recoverInterruptedOperations()

        let recorded = try await journal.confirmedAutoClose(marketId: 1)
        let left = try await journal.pending(operationId: "change")
        XCTAssertEqual(recorded, target)
        XCTAssertNil(left)
    }

    func testAnOpenWhoseSendOutcomeIsUnknownStillRecordsItsTPSL() async throws {
        let (wallet, vault) = try rebaseWallet()
        let journal = makeJournal(wallet)
        let api = AccountStubAPI(
            account: .init(), nonce: 287, tradingScreen: Self.tradingScreen(), orderBook: Self.orderBook(),
            onSendTransactions: { _, _ in throw PerpsAPIError.transport(underlying: URLError(.timedOut)) }
        )
        let trading = makeTrading(makeService(api: api, vault: vault), wallet: wallet, api: api)
        let autoClose = PerpsAutoClose(takeProfit: .init(triggerPrice: 2100), stopLoss: .init(triggerPrice: 1970))
        let prepared = try await trading.prepareOpen(.init(
            marketId: 1, side: .long, marginUsd: "100", leverage: 10, maxSlippage: 0.01, autoClose: autoClose
        ))

        let result = await trading.submit(prepared, passcodeProvider: { nil })

        guard case .submitUnknown = result else {
            return XCTFail("a timed-out send leaves the open unknown, got \(result)")
        }
        let recorded = try await journal.confirmedAutoClose(marketId: 1)
        XCTAssertEqual(recorded, autoClose)
        try await journal.removePending(operationId: prepared.operationId, includingFollowUps: true)
    }

    func testAnOpenWhosePlanMovedPastTheReviewIsRefusedAndOneWithinItIsSigned() async throws {
        let (wallet, vault) = try rebaseWallet()
        let journal = makeJournal(wallet)
        let sent = SentApprovals()
        func trading(price: String) -> PerpsTkTradingService {
            var screen = Self.tradingScreen()
            screen.market?.mark_price = price
            let api = AccountStubAPI(
                account: .init(), nonce: 287, tradingScreen: screen,
                orderBook: .init(
                    updated_at: Date(), truncated: true,
                    bids: [.init(price: price, size: "10")], asks: [.init(price: price, size: "10")]
                ),
                onSendTransactions: { _, transactions in
                    await sent.record(transactions)
                    throw PerpsAPIError.transport(underlying: URLError(.timedOut))
                }
            )
            return makeTrading(makeService(api: api, vault: vault), wallet: wallet, api: api)
        }
        let prepared = try await trading(price: "2000").prepareOpen(.init(
            marketId: 1, side: .long, marginUsd: "100", leverage: 10, maxSlippage: 0.01, autoClose: nil
        ))

        let moved = await trading(price: "2100").submit(prepared, passcodeProvider: { nil })
        let sendsAfterTheMove = await sent.transactions
        _ = await trading(price: "2030").submit(prepared, passcodeProvider: { nil })
        let sendsWithinTheTolerance = await sent.transactions

        guard case .failed(.stalePreparedTransaction) = moved else {
            return XCTFail("a plan 5% off the reviewed one must not be signed, got \(moved)")
        }
        XCTAssertTrue(sendsAfterTheMove.isEmpty)
        XCTAssertFalse(sendsWithinTheTolerance.isEmpty)
        try await journal.removePending(operationId: prepared.operationId, includingFollowUps: true)
    }

    func testPositionActionsRefuseChangesSinceConfirmationBeforeSending() async throws {
        let (wallet, vault) = try rebaseWallet()
        let sent = SentApprovals()
        func trading(size: String, margin: String) -> PerpsTkTradingService {
            var screen = Self.tradingScreen()
            screen.position = .init(value1: .init(
                market_index: 1, symbol: "ETH", side: .long, size: size, avg_entry_price: "2000",
                liquidation_price: "1700", margin_mode: .isolated, allocated_margin: margin, leverage: 10
            ))
            let api = AccountStubAPI(
                account: .init(), nonce: 287, tradingScreen: screen, orderBook: Self.orderBook(),
                onSendTransactions: { _, transactions in
                    await sent.record(transactions)
                    throw PerpsAPIError.transport(underlying: URLError(.timedOut))
                }
            )
            return makeTrading(makeService(api: api, vault: vault), wallet: wallet, api: api)
        }
        let shown = trading(size: "1", margin: "200")
        let changed = trading(size: "2", margin: "400")
        let close = try await shown.prepareClose(.init(marketId: 1)).get()
        let size = try await shown.prepareSizeChange(.init(marketId: 1, direction: .add, marginDeltaUsd: "50")).get()
        let margin = try await shown.prepareMarginChange(.init(marketId: 1, direction: .add, amountUsd: "10")).get()

        let results = [
            await changed.submit(close, passcodeProvider: { nil }),
            await changed.submit(size, passcodeProvider: { nil }),
            await changed.submit(margin, passcodeProvider: { nil }),
        ]
        for result in results {
            guard case .failed(.stalePreparedTransaction) = result else {
                return XCTFail("changed position terms must not be signed: \(result)")
            }
        }
        let sends = await sent.transactions
        XCTAssertTrue(sends.isEmpty)
    }

    func testAnAutoCloseChangeRefusesADifferentReviewedSideOrTrigger() async throws {
        let (wallet, vault) = try rebaseWallet()
        let sent = SentApprovals()
        let api = rebaseAPI(sent: sent)
        let trading = makeTrading(makeService(api: api, vault: vault), wallet: wallet, api: api)
        let prepared = try await trading.prepareAutoCloseChange(.init(
            marketId: 1, target: .init(takeProfit: .init(triggerPrice: 2100), stopLoss: nil)
        )).get()
        for review in [
            PerpsAutoCloseChangeReview(side: .short, new: prepared.review.new),
            PerpsAutoCloseChangeReview(side: .long, new: .init(takeProfit: .init(triggerPrice: 2200), stopLoss: nil)),
        ] {
            let changed = PerpsPreparedAutoCloseChangeAction(
                operationId: UUID().uuidString, walletId: wallet.id, marketId: 1,
                intent: prepared.intent, review: review
            )
            let result = await trading.submit(changed, passcodeProvider: { nil })
            guard case .failed(.stalePreparedTransaction) = result else {
                return XCTFail("a changed TP/SL review must not be signed: \(result)")
            }
        }
        let sends = await sent.transactions
        XCTAssertTrue(sends.isEmpty)
    }

    func testAnOpenReviewRefreshedWithoutItsTPSLStillAdmitsThePlanThatSignsThem() async throws {
        let (wallet, vault) = try rebaseWallet()
        let sent = SentApprovals()
        let api = AccountStubAPI(
            account: .init(), nonce: 287, tradingScreen: Self.tradingScreen(), orderBook: Self.orderBook(),
            onSendTransactions: { _, transactions in
                await sent.record(transactions)
                throw PerpsAPIError.transport(underlying: URLError(.timedOut))
            }
        )
        let trading = makeTrading(makeService(api: api, vault: vault), wallet: wallet, api: api)
        func intent(_ autoClose: PerpsAutoClose?) -> PerpsOpenMarketIntent {
            .init(marketId: 1, side: .long, marginUsd: "100", leverage: 10, maxSlippage: 0.01, autoClose: autoClose)
        }

        let refreshed = try await trading.previewOpenMarket(intent(nil)).get()
        let prepared = trading.openSubmission(
            intent(.init(takeProfit: .init(triggerPrice: 2100), stopLoss: .init(triggerPrice: 1970))),
            review: refreshed
        )
        let result = await trading.submit(prepared, passcodeProvider: { nil })

        let sends = await sent.transactions
        XCTAssertFalse(sends.isEmpty, "the confirm screen refreshes in the review scope without TP/SL, the submit plans in the session with them: \(result)")
        try await makeJournal(wallet).removePending(operationId: prepared.operationId, includingFollowUps: true)
    }

    func testASizeChangeReviewRefreshedWithoutItsTPSLStillAdmitsThePlanThatSignsThem() async throws {
        let (wallet, vault) = try rebaseWallet()
        var screen = Self.tradingScreen()
        screen.position = .init(value1: .init(
            market_index: 1, symbol: "ETH", side: .long, size: "1", avg_entry_price: "2000",
            liquidation_price: "1700", margin_mode: .isolated, allocated_margin: "200", leverage: 10
        ))
        let api = AccountStubAPI(account: .init(), nonce: 287, tradingScreen: screen, orderBook: Self.orderBook())
        let trading = makeTrading(makeService(api: api, vault: vault), wallet: wallet, api: api)
        func intent(_ update: PerpsAutoCloseUpdate) -> PerpsSizeChangeIntent {
            .init(marketId: 1, direction: .add, marginDeltaUsd: "50", autoCloseUpdate: update)
        }

        let refreshed = try await trading.previewSizeChange(intent(.unchanged)).get()
        let planned = try await trading.previewSizeChange(intent(.replace(.init(
            takeProfit: .init(triggerPrice: 2100),
            stopLoss: nil
        )))).get()

        XCTAssertTrue(refreshed.admits(planned), "the confirm screen refreshes without TP/SL: \(refreshed) vs \(planned)")
    }
}

private extension PerpsIntegratorApprovalTests {
    func rebaseWallet() throws -> (Wallet, InMemoryKeychainVault) {
        let wallet = makeWallet(id: UUID().uuidString)
        let vault = InMemoryKeychainVault()
        let store = credentials(vault, wallet)
        try store.saveL2PrivateKey(Data(repeating: 0xAB, count: 40))
        try store.saveAccount(PerpsStoredAccount(accountIndex: session.accountIndex, apiKeyIndex: session.apiKeyIndex, keyDerivationIndex: 0))
        return (wallet, vault)
    }

    func rebasePending(
        _ wallet: Wallet,
        roi: Double = 20,
        positionBaseBefore: Double? = nil,
        createdAtMillis: Int64 = PerpsPlannerMapping.nowUnixMs(),
        entrySettledAtMillis: Int64? = nil,
        parentOperationId: String = "open"
    ) -> PerpsPendingTradingAction {
        var rebase = PerpsPendingAutoCloseRebase(
            parentOperationId: parentOperationId, parentClientOrderIndex: 123, originalTriggerPrice: 2050,
            roiPercent: roi, leverage: 10, positionBaseBefore: positionBaseBefore
        )
        rebase.entrySettledAtMillis = entrySettledAtMillis
        return .init(
            operationId: "rebase", createdAtMillis: createdAtMillis, walletId: wallet.id, marketId: 1, side: .long,
            payload: .autoCloseRebase(rebase),
            expiresAtMillis: PerpsPlannerMapping.nowUnixMs() + 86_400_000,
            orderRefs: [.init(role: .takeProfit, clientOrderIndex: 777)]
        )
    }

    func rebaseAPI(
        status: String = "filled", filled: String = "1", size: String = "1", trigger: String = "2050", entry: String = "2000", ordersReadable: Bool = true, parentIndexes: [Int64] = [55], shortStopLoss: Bool = false, sent: SentApprovals
    ) -> AccountStubAPI {
        var screen = Self.tradingScreen()
        screen.position = .init(value1: .init(
            market_index: 1, symbol: "ETH", side: shortStopLoss ? .short : .long, size: size, avg_entry_price: entry,
            liquidation_price: shortStopLoss ? "2300" : "1700", margin_mode: .isolated, allocated_margin: "200", leverage: 10
        ))
        screen.open_orders = ordersReadable ? [.init(
            order_index: 281_474_976_710_656, client_order_index: 777, market_index: 1, side: shortStopLoss ? .long : .short,
            _type: .market, status: .open, category: shortStopLoss ? .stop_loss : .take_profit, base_size: "0", price: "2037",
            filled_base: "0", trigger_price: trigger, reduce_only: true,
            expires_at: Date().addingTimeInterval(86400)
        )] : nil
        return AccountStubAPI(
            account: .init(), nonce: 287, tradingScreen: screen, orderBook: Self.orderBook(),
            onPositionState: { index in
                XCTAssertEqual(index, 123)
                return .init(market_index: 1, orders: parentIndexes.map { .init(order_index: $0, status: status, filled_base: filled) })
            },
            openPosition: ordersReadable ? nil : .init(
                position: .init(market_index: 1, symbol: "ETH", side: shortStopLoss ? .short : .long, size: size),
                auto_close_known: true,
                auto_close: .init(value1: .init(
                    take_profit: .init(value1: .init(
                        order_index: 281_474_976_710_656, client_order_index: 777, trigger_price: trigger, price: "2037",
                        order_type: .market, valid_to: Int64(Date().timeIntervalSince1970) + 86400, base_size: size, share_pct: "100"
                    ))
                ))
            ),
            onSendTransactions: { _, transactions in
                await sent.record(transactions)
                throw PerpsAPIError.transport(underlying: URLError(.timedOut))
            }
        )
    }
}

private extension PerpsTkTradingService {
    func prepareOpen(_ intent: PerpsOpenMarketIntent) async throws -> PerpsPreparedTradingAction {
        try await openSubmission(intent, review: previewOpenMarket(intent).get())
    }
}
