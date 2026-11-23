import Foundation
@testable import KeeperCore
import PerpsModels
import TonSwift
import XCTest

final class PerpsAccountStoreRecoveryTests: XCTestCase {
    func testActiveSessionRecoversImmediately() async {
        let wallet = makeWallet()
        let recorder = RecoveryRecorder()
        let store = PerpsAccountStore(
            service: RecoveryAccountReading(),
            wallet: wallet,
            recoverOperations: { recorder.record() }
        )

        store.resolveIfNeeded()

        await fulfillment(of: [recorder.initialRecovery], timeout: 2)
    }

    func testWalletScopedStoresRecoverIndependently() async {
        let firstWallet = makeWallet(id: "first-wallet", keyByte: 1)
        let secondWallet = makeWallet(id: "second-wallet", keyByte: 2)
        let service = RecoveryAccountReading()
        let recorder = WalletRecoveryRecorder(
            firstWalletId: firstWallet.id,
            secondWalletId: secondWallet.id
        )
        let firstStore = PerpsAccountStore(
            service: service,
            wallet: firstWallet,
            recoverOperations: { recorder.record(walletId: firstWallet.id) }
        )
        let secondStore = PerpsAccountStore(
            service: service,
            wallet: secondWallet,
            recoverOperations: { recorder.record(walletId: secondWallet.id) }
        )

        firstStore.resolveIfNeeded()
        secondStore.resolveIfNeeded()

        await fulfillment(
            of: [recorder.firstRecovery, recorder.secondRecovery],
            timeout: 2,
            enforceOrder: false
        )
    }

    func testAResolveThatFindsNoAccountAsksForNoRecovery() async {
        let wallet = makeWallet()
        let service = RecoveryAccountReading()
        let recorder = RecoveryRecorder()
        let store = PerpsAccountStore(
            service: service,
            wallet: wallet,
            recoverOperations: { recorder.record() }
        )

        store.resolveIfNeeded()
        await fulfillment(of: [recorder.initialRecovery], timeout: 2)

        service.setStatus(.noAccount(ethAddress: "0xabc"))
        let noFurtherRecovery = recorder.expectNoFurtherRecovery()
        store.refresh()

        await fulfillment(of: [noFurtherRecovery], timeout: 0.5)
    }

    func testAStoreLetGoWhileItWaitsToRetryAResolveIsReleasedAndStopsWaiting() async {
        let service = RecoveryAccountReading()
        service.failNextRead(inPortfolio: false)
        let waiting = expectation(description: "the failed resolve waits to retry")
        let stoppedWaiting = expectation(description: "the wait ended with the store")
        let (neverElapses, elapse) = AsyncStream<Void>.makeStream()
        defer { elapse.finish() }
        var store: PerpsAccountStore? = PerpsAccountStore(
            service: service,
            wallet: makeWallet(),
            resolveRetryDelays: [1],
            waitBeforeRetry: { _ in
                waiting.fulfill()
                for await _ in neverElapses {}
                stoppedWaiting.fulfill()
            }
        )
        weak let released = store
        store?.resolveIfNeeded()
        await fulfillment(of: [waiting], timeout: 2)

        store = nil

        await fulfillment(of: [stoppedWaiting], timeout: 2)
        XCTAssertNil(released)
        XCTAssertEqual(service.statusReads, 1, "a store nobody holds must not retry its resolve")
    }

    func testAccountWithoutTradingKeyStillResolvesToActive() async {
        let wallet = makeWallet()
        let service = RecoveryAccountReading()
        let store = PerpsAccountStore(service: service, wallet: wallet)

        store.resolveIfNeeded()

        for _ in 0 ..< 200 {
            if case let .active(account) = store.currentWalletState(), account.positionsLoaded {
                XCTAssertEqual(account.accountIndex, 42)
                XCTAssertEqual(account.availableBalance, "100")
                XCTAssertEqual(account.transferableBalance, "25")
                return
            }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTFail("store never resolved to active")
    }

    func testActivationIsNeededWhereverThisDeviceCannotSign() {
        XCTAssertTrue(PerpsAccountStore.needsActivation(hasTradingKey: false, holdsTradingKey: true))
        XCTAssertTrue(PerpsAccountStore.needsActivation(hasTradingKey: true, holdsTradingKey: false))
        XCTAssertTrue(PerpsAccountStore.needsActivation(hasTradingKey: nil, holdsTradingKey: false))
        XCTAssertFalse(PerpsAccountStore.needsActivation(hasTradingKey: true, holdsTradingKey: true))
        XCTAssertFalse(PerpsAccountStore.needsActivation(hasTradingKey: nil, holdsTradingKey: true))
    }

    func testAnAccountWithoutATradingKeyHasNoPositionsAndReadsNoPortfolio() async {
        let service = RecoveryAccountReading()
        service.setStatus(.account(accountIndex: 42, hasTradingKey: false, availableBalance: "3.000000", equity: "3.500000"))
        let store = PerpsAccountStore(service: service, wallet: makeWallet())
        let active = expectation(description: "account resolved")
        active.assertForOverFulfill = false
        store.addObserver(self) { _, event in
            guard case let .didUpdate(state) = event, case .active = state else { return }
            active.fulfill()
        }
        let noPortfolioRead = service.expectNoPortfolioRead()

        store.resolveIfNeeded()

        await fulfillment(of: [active, noPortfolioRead], timeout: 0.5)
        guard case let .active(account) = store.currentWalletState() else { return XCTFail("expected an active account") }
        XCTAssertTrue(account.needsActivation)
        XCTAssertTrue(account.positionsLoaded)
        XCTAssertTrue(account.positions.isEmpty)
        XCTAssertEqual(account.availableBalance, "3.000000")
        XCTAssertEqual(account.equity, "3.500000")
    }

    func testAnAccountShowsItsBalanceWhenThePortfolioIsRefused() async {
        let service = RecoveryAccountReading()
        service.setStatus(.account(
            accountIndex: 748_924,
            hasTradingKey: true,
            hasReadOnlyToken: true,
            availableBalance: "2.066898",
            collateral: "2.035906"
        ))
        service.refusePortfolioWithoutToken()
        let store = PerpsAccountStore(service: service, wallet: makeWallet())
        let unresolved = expectation(description: "resolve gave the account up")
        unresolved.isInverted = true
        store.addObserver(self) { _, event in
            guard case let .didUpdate(state) = event, case .unresolved = state else { return }
            unresolved.fulfill()
        }

        store.resolveIfNeeded()

        await fulfillment(of: [unresolved], timeout: 0.5)
        guard case let .active(account) = store.currentWalletState() else {
            return XCTFail("a refused portfolio must not hide the account")
        }
        XCTAssertEqual(account.availableBalance, "2.066898")
        XCTAssertEqual(account.collateral, "2.035906")
        XCTAssertEqual(account.equity, "2.035906")
        XCTAssertFalse(account.positionsLoaded)
        XCTAssertFalse(account.hasReadOnlyToken)
    }

    func testAMissingReadOnlyTokenIsIssuedBeforeThePortfolioIsRead() async {
        let service = RecoveryAccountReading()
        service.setStatus(.account(accountIndex: 42, hasTradingKey: true, hasReadOnlyToken: false))
        service.refusePortfolioWithoutToken()
        let store = PerpsAccountStore(
            service: service,
            wallet: makeWallet(),
            reissueReadOnlyToken: {
                service.issueToken()
                return true
            }
        )
        let loaded = expectation(description: "portfolio read with the issued token")
        store.addObserver(self) { _, event in
            guard case let .didUpdate(state) = event, case let .active(account) = state, account.positionsLoaded else { return }
            loaded.fulfill()
        }

        store.resolveIfNeeded()

        await fulfillment(of: [loaded], timeout: 2)
        guard case let .active(account) = store.currentWalletState() else {
            return XCTFail("the token the portfolio needs must be issued before it is read")
        }
        XCTAssertFalse(account.needsActivation)
        XCTAssertEqual(account.availableBalance, "100")
    }

    func testAPortfolioRefusedForWantOfATokenIsReadAgainOnceTheTokenIsReissued() async {
        let service = RecoveryAccountReading()
        service.setStatus(.account(accountIndex: 42, hasTradingKey: true, hasReadOnlyToken: true))
        service.refusePortfolioWithoutToken()
        let store = PerpsAccountStore(
            service: service,
            wallet: makeWallet(),
            reissueReadOnlyToken: {
                service.issueToken()
                return true
            }
        )
        let loaded = expectation(description: "portfolio read with the reissued token")
        store.addObserver(self) { _, event in
            guard case let .didUpdate(state) = event, case let .active(account) = state, account.positionsLoaded else { return }
            loaded.fulfill()
        }

        store.resolveIfNeeded()

        await fulfillment(of: [loaded], timeout: 2)
    }

    func testFirstDepositRefreshesAnInactiveAccountAndKeepsFundingOutsideActiveState() async {
        let service = RecoveryAccountReading()
        service.setStatus(.noAccount(ethAddress: "0xabc"))
        let store = PerpsAccountStore(service: service, wallet: makeWallet())
        let inactive = expectation(description: "inactive account")
        let active = expectation(description: "account refreshed after first deposit")
        active.assertForOverFulfill = false
        store.addObserver(self) { _, event in
            guard case let .didUpdate(state) = event else { return }
            switch state {
            case .inactive: inactive.fulfill()
            case .active: active.fulfill()
            default: break
            }
        }
        store.resolveIfNeeded()
        await fulfillment(of: [inactive], timeout: 2)

        let asset = PerpsFundingAsset(assetId: "usdc", symbol: "USDC", decimals: 6)
        var deposit = PerpsPendingDeposit(
            stage: .registeredPending, route: .directGateway, beneficiary: "0xabc",
            sourceAsset: asset, sourceAmountUnits: "25000000", targetAsset: asset
        )
        var operation = PerpsPendingFundingOperation(
            operationId: "deposit", walletId: "wallet", walletIdentity: "identity", environment: "test",
            details: .deposit(deposit)
        )
        store.applyFundingState(.loaded([operation]))
        XCTAssertEqual(store.currentFundingState().operations, [operation])
        XCTAssertEqual(store.fundingActivity().inFlight, ["deposit"])
        guard case .inactive = store.currentWalletState() else { return XCTFail("funding must not activate the account itself") }

        service.setStatus(.account(accountIndex: 42))
        deposit.stage = .credited
        deposit.accountIndex = 42
        operation.details = .deposit(deposit)
        store.applyFundingState(.loaded([operation]))
        await fulfillment(of: [active], timeout: 2)
        XCTAssertEqual(store.currentFundingState().operations, [operation])
        XCTAssertEqual(store.fundingActivity().completed, ["deposit"])
    }

    func testAWithdrawalRefusedForItsNonceIsNotReportedAsSending() {
        let store = PerpsAccountStore(service: RecoveryAccountReading(), wallet: makeWallet())
        func withdraw(_ id: String, failureReason: String?) -> PerpsPendingFundingOperation {
            PerpsPendingFundingOperation(
                operationId: id, walletId: "wallet", walletIdentity: "identity", environment: "test",
                details: .withdraw(PerpsPendingWithdraw(
                    stage: .unknown, accountIndex: 42, apiKeyIndex: 1, chainId: 304,
                    assetIndex: 0, routeType: 0, amountUnits: "25000000", failureReason: failureReason
                ))
            )
        }

        store.applyFundingState(.loaded([
            withdraw("refused", failureReason: PerpsWithdrawService.resignRequiredReason),
            withdraw("ambiguous", failureReason: nil),
        ]))

        let activity = store.fundingActivity()
        XCTAssertEqual(activity.inFlight, ["ambiguous"])
        XCTAssertEqual(activity.withdrawals, ["refused", "ambiguous"])
        XCTAssertTrue(activity.pending.isEmpty)
        XCTAssertTrue(activity.failed.isEmpty)
    }

    func testFailedDepositsAndRejectedWithdrawalsAreReportedAsFailed() {
        let store = PerpsAccountStore(service: RecoveryAccountReading(), wallet: makeWallet())
        let asset = PerpsFundingAsset(assetId: "usdc", symbol: "USDC", decimals: 6)
        func deposit(_ id: String, _ stage: PerpsDepositStage) -> PerpsPendingFundingOperation {
            PerpsPendingFundingOperation(
                operationId: id, walletId: "wallet", walletIdentity: "identity", environment: "test",
                details: .deposit(PerpsPendingDeposit(
                    stage: stage, route: .directGateway, beneficiary: "0xabc",
                    sourceAsset: asset, sourceAmountUnits: "25000000", targetAsset: asset
                ))
            )
        }
        let withdraw = PerpsPendingFundingOperation(
            operationId: "rejected", walletId: "wallet", walletIdentity: "identity", environment: "test",
            details: .withdraw(PerpsPendingWithdraw(
                stage: .rejected, accountIndex: 42, apiKeyIndex: 1, chainId: 304,
                assetIndex: 0, routeType: 0, amountUnits: "25000000"
            ))
        )

        store.applyFundingState(.loaded([
            deposit("failed", .failed), deposit("refunded", .refunded), deposit("unconfirmed", .unconfirmed), withdraw,
        ]))

        XCTAssertEqual(store.fundingActivity().failed, ["failed", "refunded", "rejected"])
        XCTAssertEqual(store.fundingActivity().withdrawals, ["rejected"])
    }

    func testAcknowledgedDepositStatusesAreSharedAndRestoredWithoutStaleSnapshotsUndoingThem() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let journal = PerpsPendingJournal(walletId: "wallet", environment: "test", directoryURL: directory)
        let asset = PerpsFundingAsset(assetId: "usdc", symbol: "USDC", decimals: 6)
        let operation = PerpsPendingFundingOperation(
            operationId: "failed", walletId: "wallet", walletIdentity: "identity", environment: "test",
            details: .deposit(PerpsPendingDeposit(
                stage: .failed, route: .directGateway, beneficiary: "0xabc",
                sourceAsset: asset, sourceAmountUnits: "25000000", targetAsset: asset
            ))
        )
        _ = try await journal.saveFundingIfAbsent(operation)
        let persisted = expectation(description: "outcome acknowledgement persisted")
        let store = PerpsAccountStore(
            service: RecoveryAccountReading(), wallet: makeWallet(),
            persistDepositAcknowledgements: { ids in
                try await journal.acknowledgeDepositStatuses(ids)
                persisted.fulfill()
            }
        )
        store.applyFundingState(.loaded([operation]))
        store.acknowledgeDepositStatuses(["failed", "missing"])
        XCTAssertEqual(store.fundingActivity().acknowledgedDepositIds, ["failed"])
        store.applyFundingState(.unavailable(lastKnown: [operation]))
        XCTAssertEqual(store.fundingActivity().acknowledgedDepositIds, ["failed"])
        await fulfillment(of: [persisted], timeout: 2)

        let reopenedJournal = PerpsPendingJournal(walletId: "wallet", environment: "test", directoryURL: directory)
        let restored = PerpsAccountStore(service: RecoveryAccountReading(), wallet: makeWallet())
        try restored.applyFundingState(.loaded(await reopenedJournal.allFunding()))
        XCTAssertEqual(restored.fundingActivity().acknowledgedDepositIds, ["failed"])
        let otherWallet = PerpsAccountStore(service: RecoveryAccountReading(), wallet: makeWallet(id: "other-wallet"))
        XCTAssertTrue(otherWallet.fundingActivity().acknowledgedDepositIds.isEmpty)
    }

    func testADepositIsFoundByTheTransactionThatPaidIt() {
        let asset = PerpsFundingAsset(assetId: "usdc", symbol: "USDC", decimals: 6)
        let deposit = PerpsPendingDeposit(
            stage: .registeredPending, route: .directGateway, beneficiary: "0xabc",
            sourceAsset: asset, sourceAmountUnits: "25000000", targetAsset: asset, sourceTxHash: "0xgateway"
        )
        let operation = PerpsPendingFundingOperation(
            operationId: "deposit", walletId: "wallet", walletIdentity: "identity", environment: "test",
            details: .deposit(deposit)
        )

        XCTAssertEqual(operation.transactionHashes, ["0xgateway"])
    }

    func testWithdrawalRefreshesTheAccountOnceWhenLighterDebitsIt() async {
        let service = RecoveryAccountReading()
        let store = PerpsAccountStore(service: service, wallet: makeWallet())
        store.resolveIfNeeded()
        await waitUntil { if case .active = store.currentWalletState() { true } else { false } }
        let readsBefore = service.statusReads

        var withdraw = PerpsPendingWithdraw(
            stage: .sending, accountIndex: 42, apiKeyIndex: 1, chainId: 304,
            assetIndex: 0, routeType: 0, amountUnits: "25000000"
        )
        var operation = PerpsPendingFundingOperation(
            operationId: "withdraw", walletId: "wallet", walletIdentity: "identity", environment: "test",
            details: .withdraw(withdraw)
        )
        store.applyFundingState(.loaded([operation]))
        XCTAssertEqual(store.fundingActivity(), PerpsFundingActivity(inFlight: ["withdraw"], withdrawals: ["withdraw"]))
        XCTAssertEqual(service.statusReads, readsBefore, "nothing is debited before Lighter accepts")

        withdraw.stage = .accepted
        operation.details = .withdraw(withdraw)
        store.applyFundingState(.loaded([operation]))
        XCTAssertEqual(store.fundingActivity().pending, ["withdraw"])
        await waitUntil { service.statusReads > readsBefore }
        let readsAfterDebit = service.statusReads

        withdraw.stage = .settled
        withdraw.l1TxHash = "0xpayout"
        operation.details = .withdraw(withdraw)
        store.applyFundingState(.loaded([operation]))
        let settled = store.fundingActivity()
        XCTAssertEqual(
            settled,
            PerpsFundingActivity(isBalanceRefreshing: settled.isBalanceRefreshing, completed: ["withdraw"], transactions: ["withdraw": ["0xpayout"]], withdrawals: ["withdraw"])
        )
        XCTAssertEqual(service.statusReads, readsAfterDebit, "settling moves no Perps balance")
    }

    private func waitUntil(_ condition: () -> Bool) async {
        for _ in 0 ..< 200 where !condition() {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertTrue(condition())
    }

    func testALifecycleNoticeDoesNotRevertAStateStillWaitingInTheQueue() async {
        let store = PerpsAccountStore(service: RecoveryAccountReading(), wallet: makeWallet())
        store.resolveIfNeeded()
        await store.resolveTaskForTesting?.value
        await store.flushStateForTesting()
        let gate = DispatchSemaphore(value: 0)
        store.updateState({ _ in
            gate.wait()
            return nil
        }, completion: nil)

        store.updateState({ _ in
            .init(newState: .active(PerpsAccount(accountIndex: 42, availableBalance: "105")))
        }, completion: nil)
        store.tradeBegan(operationId: "adjust", marketId: 1, .adjusting(.add, baseSizeBefore: 1))
        gate.signal()
        await store.flushStateForTesting()

        guard case let .active(account) = store.currentWalletState() else { return XCTFail("the account must stay active") }
        XCTAssertEqual(account.availableBalance, "105")
    }

    func testAConfirmedMarketOpenShowsTheCountedPosition() {
        let store = PerpsAccountStore(service: RecoveryAccountReading(), wallet: makeWallet())
        let opening = PerpsOpeningDescriptor(
            marketId: 1, symbol: "ETH", side: .long, marginUsd: 3, leverage: 5, isLimit: false, liquidationPrice: 1900
        )
        let counted = PerpsCountedPosition(baseSize: 0.0063, entryPrice: 2345.02, leverage: 5, isolatedMarginUsd: 2.953767)
        store.tradeBegan(operationId: "open", marketId: 1, .opening(opening))

        store.positionCounted(operationId: "open", counted)
        XCTAssertEqual(store.lifecycle(marketId: 1), .opening(opening), "only a confirmed open is shown")

        store.tradeSettled(operationId: "open", succeeded: true)
        store.positionCounted(operationId: "open", counted)
        guard case let .open(summary) = store.lifecycle(marketId: 1) else { return XCTFail("the count stands in") }
        XCTAssertEqual(summary.baseSize, 0.0063)
        XCTAssertEqual(summary.entryPrice, 2345.02)
        XCTAssertEqual(summary.marginUsd, 2.953767)
        XCTAssertEqual(summary.liquidationPrice, 1900)
    }

    func testAnOpenWithoutAnEstimateOrAtALimitKeepsWaitingForThePortfolio() {
        let store = PerpsAccountStore(service: RecoveryAccountReading(), wallet: makeWallet())
        let counted = PerpsCountedPosition(baseSize: 1, entryPrice: 100, leverage: 5, isolatedMarginUsd: nil)
        let unestimated = PerpsOpeningDescriptor(marketId: 1, symbol: "ETH", side: .long, marginUsd: 20, leverage: 5, isLimit: false)
        let limit = PerpsOpeningDescriptor(
            marketId: 2, symbol: "BTC", side: .long, marginUsd: 20, leverage: 5, isLimit: true, liquidationPrice: 80
        )
        store.tradeBegan(operationId: "market", marketId: 1, .opening(unestimated))
        store.tradeBegan(operationId: "limit", marketId: 2, .opening(limit))
        store.tradeSettled(operationId: "market", succeeded: true)
        store.tradeSettled(operationId: "limit", succeeded: true)

        store.positionCounted(operationId: "market", counted)
        store.positionCounted(operationId: "limit", counted)

        XCTAssertEqual(store.lifecycle(marketId: 1), .opening(unestimated))
        XCTAssertEqual(store.lifecycle(marketId: 2), .opening(limit))
    }

    func testClosingACountedPositionShowsTheCloseAndLeavesTheMarketFlat() async throws {
        let store = PerpsAccountStore(service: RecoveryAccountReading(), wallet: makeWallet())
        let counted = try XCTUnwrap(openCounted(in: store, marketId: 1))

        store.tradeBegan(operationId: "close", marketId: 1, .closing)
        XCTAssertEqual(store.lifecycle(marketId: 1), .closing(counted))

        store.tradeSettled(operationId: "close", succeeded: true)
        store.refresh()
        for _ in 0 ..< 100 where store.lifecycle(marketId: 1) != .flat {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertEqual(store.lifecycle(marketId: 1), .flat)
    }

    func testAPortfolioThatHasNotListedACountedPositionLeavesItsCloseRunning() async throws {
        let store = PerpsAccountStore(service: RecoveryAccountReading(), wallet: makeWallet())
        let counted = try XCTUnwrap(openCounted(in: store, marketId: 1))
        store.tradeBegan(operationId: "close", marketId: 1, .closing)

        store.refresh()
        await store.resolveTaskForTesting?.value
        XCTAssertEqual(store.lifecycle(marketId: 1), .closing(counted))

        store.tradeSettled(operationId: "close", succeeded: true)
        store.refresh()
        await store.resolveTaskForTesting?.value
        XCTAssertEqual(store.lifecycle(marketId: 1), .flat)
    }

    func testAFailedCloseOfACountedPositionKeepsShowingIt() throws {
        let store = PerpsAccountStore(service: RecoveryAccountReading(), wallet: makeWallet())
        let counted = try XCTUnwrap(openCounted(in: store, marketId: 1))

        store.tradeBegan(operationId: "close", marketId: 1, .closing)
        store.tradeSettled(operationId: "close", succeeded: false)

        XCTAssertEqual(store.lifecycle(marketId: 1), .open(counted))
    }

    func testAdjustingACountedPositionKeepsShowingIt() throws {
        let store = PerpsAccountStore(service: RecoveryAccountReading(), wallet: makeWallet())
        let sized = try XCTUnwrap(openCounted(in: store, marketId: 1))
        let margined = try XCTUnwrap(openCounted(in: store, marketId: 2))

        store.tradeBegan(operationId: "add", marketId: 1, .adjusting(.add, baseSizeBefore: sized.baseSize))
        store.tradeBegan(
            operationId: "margin",
            marketId: 2,
            .adjustingMargin(.add, allocatedMarginBefore: margined.marginUsd, amountUsd: 1)
        )

        XCTAssertEqual(store.lifecycle(marketId: 1), .adjusting(sized, .add))
        XCTAssertEqual(store.lifecycle(marketId: 2), .adjustingMargin(margined, .add, amountUsd: 1))
    }

    func testAFailedResolveIsRetriedWithoutAnotherCaller() async {
        let service = RecoveryAccountReading()
        let store = PerpsAccountStore(
            service: service,
            wallet: makeWallet(),
            resolveRetryDelays: [1],
            waitBeforeRetry: { _ in }
        )
        service.failNextRead(inPortfolio: false)

        store.resolveIfNeeded()
        await store.resolveTaskForTesting?.value
        await store.flushStateForTesting()

        XCTAssertEqual(service.statusReads, 2)
        guard case .active = store.currentWalletState() else { return XCTFail("the retry must settle the account") }
    }

    func testResolveIfNeededAfterTheRetriesGaveUpResolvesAgain() async {
        let service = RecoveryAccountReading()
        let store = PerpsAccountStore(
            service: service,
            wallet: makeWallet(),
            resolveRetryDelays: [],
            waitBeforeRetry: { _ in }
        )
        service.failNextRead(inPortfolio: false)
        store.resolveIfNeeded()
        await store.resolveTaskForTesting?.value
        await store.flushStateForTesting()
        guard case .unresolved = store.currentWalletState() else { return XCTFail("the failed resolve must give up") }

        store.resolveIfNeeded()
        await store.resolveTaskForTesting?.value
        await store.flushStateForTesting()

        XCTAssertEqual(service.statusReads, 2)
        guard case .active = store.currentWalletState() else {
            return XCTFail("a later resolveIfNeeded must settle the account")
        }
    }

    /// A refresh that starts while a retry is waiting takes the retry down with the failed
    /// resolve it belongs to: waking up must not read again or replace the refresh.
    func testARefreshDuringTheRetryWaitSupersedesTheRetry() async {
        let service = RecoveryAccountReading()
        let (retryWaits, retryWaitStarted) = AsyncStream<Void>.makeStream()
        let (neverReleased, release) = AsyncStream<Void>.makeStream()
        let store = PerpsAccountStore(
            service: service,
            wallet: makeWallet(),
            resolveRetryDelays: [1],
            waitBeforeRetry: { _ in
                retryWaitStarted.yield()
                for await _ in neverReleased {}
            }
        )
        service.failNextRead(inPortfolio: false)
        store.resolveIfNeeded()
        var waits = retryWaits.makeAsyncIterator()
        await waits.next()
        let failedResolve = store.resolveTaskForTesting

        store.refresh()
        await failedResolve?.value
        await store.resolveTaskForTesting?.value
        await store.flushStateForTesting()

        XCTAssertEqual(service.statusReads, 2)
        guard case .active = store.currentWalletState() else { return XCTFail("the refresh must stay settled") }
        release.finish()
    }

    func testDepositCompletionWaitsForThePortfolioBalance() async {
        let service = RecoveryAccountReading()
        let store = PerpsAccountStore(service: service, wallet: makeWallet())
        let started = expectation(description: "portfolio read started")
        let (hold, release) = AsyncStream<Void>.makeStream()
        defer { release.finish() }
        service.beforeNextPortfolio {
            started.fulfill()
            for await _ in hold {
                break
            }
        }
        let asset = PerpsFundingAsset(assetId: "usdc", symbol: "USDC", decimals: 6)
        store.applyFundingState(.loaded([PerpsPendingFundingOperation(
            operationId: "credited", walletId: "wallet", walletIdentity: "identity", environment: "test",
            details: .deposit(.init(
                stage: .credited, route: .directGateway, beneficiary: "0xabc",
                sourceAsset: asset, sourceAmountUnits: "25000000", targetAsset: asset, accountIndex: 42
            ))
        )]))
        await fulfillment(of: [started], timeout: 2)
        XCTAssertTrue(store.fundingActivity().isBalanceRefreshing)
        release.finish()
        await store.resolveTaskForTesting?.value
        await store.flushStateForTesting()
        XCTAssertFalse(store.fundingActivity().isBalanceRefreshing)
        guard case let .active(account) = store.currentWalletState() else { return XCTFail("missing account") }
        XCTAssertEqual(account.availableBalance, "100")
    }

    func testFailedFundingRefreshRetriesOnResumeWithoutAnotherFundingChange() async {
        let service = RecoveryAccountReading()
        let store = PerpsAccountStore(service: service, wallet: makeWallet())
        let failed = expectation(description: "failed refresh finished")
        let active = expectation(description: "resumed account refresh")
        active.assertForOverFulfill = false
        store.addObserver(self) { _, event in
            guard case let .didUpdate(state) = event else { return }
            switch state {
            case .unresolved: failed.fulfill()
            case .active: active.fulfill()
            default: break
            }
        }
        service.failNextRead(inPortfolio: false)
        let asset = PerpsFundingAsset(assetId: "usdc", symbol: "USDC", decimals: 6)
        let funding = PerpsFundingState.loaded([PerpsPendingFundingOperation(
            operationId: "credited", walletId: "wallet", walletIdentity: "identity", environment: "test",
            details: .deposit(.init(
                stage: .credited, route: .directGateway, beneficiary: "0xabc",
                sourceAsset: asset, sourceAmountUnits: "25000000", targetAsset: asset, accountIndex: 42
            ))
        )])
        store.applyFundingState(funding)
        await fulfillment(of: [failed], timeout: 2)
        store.applyFundingState(funding)
        store.retryFundingRefreshIfNeeded()
        await fulfillment(of: [active], timeout: 2)
        await store.resolveTaskForTesting?.value
        await store.flushStateForTesting()
        XCTAssertEqual(store.currentFundingState(), funding)

        let noFurtherRead = service.expectNoFurtherRead()
        store.retryFundingRefreshIfNeeded()
        await fulfillment(of: [noFurtherRead], timeout: 0.1)
    }
}

private extension PerpsAccountStoreRecoveryTests {
    func openCounted(in store: PerpsAccountStore, marketId: Int64) -> PerpsPositionSummary? {
        let operationId = "open-\(marketId)"
        let opening = PerpsOpeningDescriptor(
            marketId: marketId, symbol: "ETH", side: .long, marginUsd: 3, leverage: 5, isLimit: false, liquidationPrice: 1900
        )
        store.tradeBegan(operationId: operationId, marketId: marketId, .opening(opening))
        store.tradeSettled(operationId: operationId, succeeded: true)
        store.positionCounted(
            operationId: operationId,
            PerpsCountedPosition(baseSize: 0.0063, entryPrice: 2345.02, leverage: 5, isolatedMarginUsd: 2.953767)
        )
        guard case let .open(counted) = store.lifecycle(marketId: marketId) else { return nil }
        return counted
    }

    func makeWallet(id: String = "recovery-wallet", keyByte: UInt8 = 1) -> Wallet {
        let publicKey = TonSwift.PublicKey(data: Data(repeating: keyByte, count: 32))
        return Wallet(
            id: id,
            identity: WalletIdentity(network: .mainnet, kind: .Regular(publicKey, .v4R2)),
            metaData: WalletMetaData(label: "Recovery", tintColor: .defaultColor, icon: .icon(.wallet)),
            setupSettings: WalletSetupSettings(isSetupFinished: true),
            batterySettings: BatterySettings()
        )
    }
}

private final class RecoveryRecorder: @unchecked Sendable {
    let initialRecovery = XCTestExpectation(description: "initial operation recovery")

    private let lock = NSLock()
    private var count = 0
    private var furtherRecovery: XCTestExpectation?

    func expectNoFurtherRecovery() -> XCTestExpectation {
        let expectation = XCTestExpectation(description: "stopped scope runs no further recovery")
        expectation.isInverted = true
        lock.withLock { furtherRecovery = expectation }
        return expectation
    }

    func record() {
        let (current, further) = lock.withLock {
            count += 1
            return (count, furtherRecovery)
        }
        if current == 1 {
            initialRecovery.fulfill()
        }
        further?.fulfill()
    }
}

private final class RecoveryAccountReading: PerpsAccountReading, @unchecked Sendable {
    private let lock = NSLock()
    private var reads = 0
    private var statusResult: PerpsAccountStatus = .account(accountIndex: 42)
    private var failureInPortfolio: Bool?
    private var beforePortfolio: (@Sendable () async -> Void)?
    private var portfolioNeedsToken = false
    private var tokenIssued = false
    private var unexpectedRead: XCTestExpectation?
    private var unexpectedPortfolioRead: XCTestExpectation?

    var statusReads: Int {
        lock.withLock { reads }
    }

    func expectNoPortfolioRead() -> XCTestExpectation {
        let expectation = XCTestExpectation(description: "an account without a key reads no portfolio")
        expectation.isInverted = true
        lock.withLock { unexpectedPortfolioRead = expectation }
        return expectation
    }

    func expectNoFurtherRead() -> XCTestExpectation {
        let expectation = XCTestExpectation(description: "successful refresh clears retry")
        expectation.isInverted = true
        lock.withLock { unexpectedRead = expectation }
        return expectation
    }

    func failNextRead(inPortfolio: Bool) {
        lock.withLock {
            statusResult = .account(accountIndex: 42)
            failureInPortfolio = inPortfolio
        }
    }

    private func takeFailure(inPortfolio: Bool) -> Bool {
        lock.withLock {
            guard failureInPortfolio == inPortfolio else { return false }
            failureInPortfolio = nil
            return true
        }
    }

    func setStatus(_ status: PerpsAccountStatus) {
        lock.withLock { statusResult = status }
    }

    func refusePortfolioWithoutToken() {
        lock.withLock { portfolioNeedsToken = true }
    }

    func issueToken() {
        lock.withLock { tokenIssued = true }
    }

    func status(wallet _: Wallet) async -> PerpsAccountStatus {
        lock.withLock {
            reads += 1
            return unexpectedRead
        }?.fulfill()
        if takeFailure(inPortfolio: false) {
            return .unavailable(reason: "offline")
        }
        return lock.withLock { statusResult }
    }

    func beforeNextPortfolio(_ action: @escaping @Sendable () async -> Void) {
        lock.withLock { beforePortfolio = action }
    }

    func portfolio(wallet _: Wallet) async throws -> PerpsAccountSnapshot? {
        let before = lock.withLock {
            let action = beforePortfolio
            beforePortfolio = nil
            return action
        }
        await before?()
        lock.withLock { unexpectedPortfolioRead }?.fulfill()
        if takeFailure(inPortfolio: true) {
            throw URLError(.notConnectedToInternet)
        }
        if lock.withLock({ portfolioNeedsToken && !tokenIssued }) {
            throw PerpsAPIError.badStatus(PerpsAPIFailure(
                httpStatus: 400,
                code: "readonly_token_unavailable",
                message: nil,
                retryable: false,
                reason: nil
            ))
        }
        return PerpsAccountSnapshot(availableBalance: "100", transferableBalance: "25")
    }

    func watchPositions(
        wallet _: Wallet,
        pollInterval _: TimeInterval,
        focus _: @escaping @Sendable () -> PerpsWatchFocus,
        onUpdate _: @escaping @Sendable (PerpsAccountTick) -> Void,
        onInterrupted _: @escaping @Sendable () -> Void
    ) -> PerpsPositionsWatch {
        PerpsPositionsWatch {}
    }

    func tradingSnapshot(wallet _: Wallet, marketId _: Int64, positionId _: String?) async throws -> PerpsTradingSnapshot {
        PerpsTradingSnapshot(flags: .testAllEnabled, orders: PerpsActiveOrders(limitOrders: [], triggerOrders: []))
    }
}

private final class WalletRecoveryRecorder: @unchecked Sendable {
    let firstRecovery = XCTestExpectation(description: "first wallet recovered")
    let secondRecovery = XCTestExpectation(description: "second wallet recovered")

    private let lock = NSLock()
    private let firstWalletId: String
    private let secondWalletId: String
    private var firstRecoveryCount = 0
    private var secondRecoveryCount = 0

    init(firstWalletId: String, secondWalletId: String) {
        self.firstWalletId = firstWalletId
        self.secondWalletId = secondWalletId
    }

    func record(walletId: String) {
        let action = lock.withLock { () -> Int in
            if walletId == firstWalletId {
                firstRecoveryCount += 1
                return firstRecoveryCount == 1 ? 1 : 0
            }
            if walletId == secondWalletId {
                secondRecoveryCount += 1
                return secondRecoveryCount == 1 ? 2 : 0
            }
            return 0
        }
        switch action {
        case 1: firstRecovery.fulfill()
        case 2: secondRecovery.fulfill()
        default: break
        }
    }
}

extension PerpsTradingFlags {
    static let testAllEnabled: PerpsTradingFlags? = PerpsTradingFlags(
        openEnabled: true,
        closeEnabled: true,
        cancelEnabled: true,
        addMarginEnabled: true,
        removeMarginEnabled: true,
        autoCloseEnabled: true
    )
}
