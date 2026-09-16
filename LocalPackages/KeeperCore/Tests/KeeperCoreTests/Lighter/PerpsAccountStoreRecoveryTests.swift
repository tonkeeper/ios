import ChainKit
import Foundation
@testable import KeeperCore
import TonSwift
import XCTest

final class PerpsAccountStoreRecoveryTests: XCTestCase {
    func testActiveSessionRecoversImmediatelyAndAfterTransactionUpdate() async {
        let wallet = makeWallet()
        let service = RecoveryAccountReading()
        let recorder = RecoveryRecorder()
        let store = PerpsAccountStore(
            service: service,
            wallet: wallet,
            recoverOperations: { recorder.record() }
        )

        store.resolveIfNeeded()

        await fulfillment(of: [service.firstWatchOpened, recorder.initialRecovery], timeout: 2)
        service.emitTransactionUpdate()
        await fulfillment(of: [recorder.updateRecovery], timeout: 2)
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
            of: [service.firstWatchOpened, service.secondWatchOpened, recorder.firstRecovery, recorder.secondRecovery],
            timeout: 2,
            enforceOrder: false
        )

        service.emitTransactionUpdate(walletId: firstWallet.id)
        await fulfillment(of: [recorder.firstUpdateRecovery, recorder.secondUnexpectedRecovery], timeout: 1.0)
    }

    func testStopOperationRecoveryIgnoresLateTransactionUpdate() async {
        let wallet = makeWallet()
        let service = RecoveryAccountReading()
        let recorder = RecoveryRecorder()
        let store = PerpsAccountStore(
            service: service,
            wallet: wallet,
            recoverOperations: { recorder.record() }
        )

        store.resolveIfNeeded()
        await fulfillment(of: [service.firstWatchOpened, recorder.initialRecovery], timeout: 2)

        store.beginActivation()
        await fulfillment(of: [service.watchCancelled], timeout: 2)
        let noFurtherRecovery = recorder.expectNoFurtherRecovery()
        service.emitTransactionUpdate()
        await fulfillment(of: [noFurtherRecovery], timeout: 0.5)
    }
}

private extension PerpsAccountStoreRecoveryTests {
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
    let updateRecovery = XCTestExpectation(description: "transaction update recovery")

    private let lock = NSLock()
    private var count = 0
    private var furtherRecovery: XCTestExpectation?

    func expectNoFurtherRecovery() -> XCTestExpectation {
        let expectation = XCTestExpectation(description: "stopped recovery ignores late transaction update")
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
        } else if current == 2 {
            updateRecovery.fulfill()
        }
        further?.fulfill()
    }
}

private final class RecoveryAccountReading: PerpsAccountReading, @unchecked Sendable {
    let firstWatchOpened = XCTestExpectation(description: "first transaction updates watch opened")
    let secondWatchOpened = XCTestExpectation(description: "second transaction updates watch opened")
    let watchCancelled = XCTestExpectation(description: "transaction updates watch cancelled")

    private let lock = NSLock()
    private var transactionUpdates = [String: @Sendable () -> Void]()
    private var watchCount = 0
    private var didReportCancellation = false

    func status(wallet _: Wallet) async -> LighterPerpsStatus {
        .active(accountIndex: 42, apiKeyIndex: 3)
    }

    func portfolio(wallet _: Wallet, accountIndex: Int64) async throws -> PerpsPortfolio? {
        PerpsPortfolio(
            accountIndex: accountIndex,
            collateral: "100",
            availableBalance: "100",
            totalAssetValue: "100",
            positions: []
        )
    }

    func watchPositions(
        wallet _: Wallet,
        accountIndex _: Int64,
        onUpdate _: @escaping @Sendable ([PerpsPositionSummary]) -> Void,
        onReconnecting _: @escaping @Sendable () -> Void
    ) -> PerpsPositionsWatch {
        PerpsPositionsWatch {}
    }

    func watchTransactionUpdates(
        wallet: Wallet,
        onUpdate: @escaping @Sendable () -> Void,
        onReconnecting _: @escaping @Sendable () -> Void
    ) async throws -> PerpsTransactionUpdatesWatch? {
        let currentWatchCount = lock.withLock {
            transactionUpdates[wallet.id] = onUpdate
            watchCount += 1
            return watchCount
        }
        if currentWatchCount == 1 {
            firstWatchOpened.fulfill()
        } else if currentWatchCount == 2 {
            secondWatchOpened.fulfill()
        }
        return PerpsTransactionUpdatesWatch { [weak self] in
            guard let self else { return }
            let shouldReport = self.lock.withLock {
                guard !self.didReportCancellation else { return false }
                self.didReportCancellation = true
                return true
            }
            if shouldReport { self.watchCancelled.fulfill() }
        }
    }

    func activeTriggerOrders(
        wallet _: Wallet,
        accountIndex _: Int64,
        marketId _: Int64
    ) async throws -> [PerpsTriggerOrderSummary] {
        []
    }

    func recentActivity(
        wallet _: Wallet,
        accountIndex _: Int64,
        marketId _: Int64,
        limit _: Int
    ) async throws -> [PerpsActivityItem] {
        []
    }

    func emitTransactionUpdate(walletId: String = "recovery-wallet") {
        let update = lock.withLock { transactionUpdates[walletId] }
        update?()
    }
}

private final class WalletRecoveryRecorder: @unchecked Sendable {
    let firstRecovery = XCTestExpectation(description: "first wallet recovered")
    let secondRecovery = XCTestExpectation(description: "second wallet recovered")
    let firstUpdateRecovery = XCTestExpectation(description: "first wallet update recovered")
    let secondUnexpectedRecovery = XCTestExpectation(description: "first wallet update does not recover second wallet")

    private let lock = NSLock()
    private let firstWalletId: String
    private let secondWalletId: String
    private var firstRecoveryCount = 0
    private var secondRecoveryCount = 0

    init(firstWalletId: String, secondWalletId: String) {
        self.firstWalletId = firstWalletId
        self.secondWalletId = secondWalletId
        secondUnexpectedRecovery.isInverted = true
    }

    func record(walletId: String) {
        let action = lock.withLock { () -> Int in
            if walletId == firstWalletId {
                firstRecoveryCount += 1
                return firstRecoveryCount == 1 ? 1 : 3
            }
            if walletId == secondWalletId {
                secondRecoveryCount += 1
                return secondRecoveryCount == 1 ? 2 : 4
            }
            return 0
        }
        switch action {
        case 1: firstRecovery.fulfill()
        case 2: secondRecovery.fulfill()
        case 3: firstUpdateRecovery.fulfill()
        case 4: secondUnexpectedRecovery.fulfill()
        default: break
        }
    }
}
