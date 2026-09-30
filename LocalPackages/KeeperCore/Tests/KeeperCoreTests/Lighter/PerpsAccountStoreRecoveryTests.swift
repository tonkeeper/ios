import Foundation
@testable import KeeperCore
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

    func testStoppedRecoveryDoesNotRunAgain() async {
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

    func testAccountWithoutTradingKeyStillResolvesToActive() async {
        let wallet = makeWallet()
        let service = RecoveryAccountReading()
        let store = PerpsAccountStore(service: service, wallet: wallet)

        store.resolveIfNeeded()

        for _ in 0 ..< 200 {
            if case let .active(account) = store.currentWalletState() {
                XCTAssertEqual(account.accountIndex, 42)
                XCTAssertEqual(account.availableBalance, "100")
                return
            }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTFail("store never resolved to active")
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
    private var statusResult: PerpsAccountStatus = .account(accountIndex: 42)

    func setStatus(_ status: PerpsAccountStatus) {
        lock.withLock { statusResult = status }
    }

    func status(wallet _: Wallet) async -> PerpsAccountStatus {
        lock.withLock { statusResult }
    }

    func portfolio(wallet _: Wallet) async throws -> PerpsAccountSnapshot? {
        PerpsAccountSnapshot(availableBalance: "100")
    }

    func watchPositions(
        wallet _: Wallet,
        onUpdate _: @escaping @Sendable ([PerpsPositionSummary]) -> Void,
        onInterrupted _: @escaping @Sendable () -> Void
    ) -> PerpsPositionsWatch {
        PerpsPositionsWatch {}
    }

    func tradingSnapshot(wallet _: Wallet, marketId _: Int64, positionId _: String?) async throws -> PerpsTradingSnapshot {
        PerpsTradingSnapshot(flags: .testAllEnabled, orders: PerpsActiveOrders(limitOrders: [], triggerOrders: []))
    }

    func recentActivity(wallet _: Wallet, marketId _: Int64, limit _: Int) async throws -> [PerpsActivityItem] {
        []
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
