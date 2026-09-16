import Foundation
@testable import KeeperCore
import TonSwift
import XCTest

final class BalanceRefreshWaitersTests: XCTestCase {
    private let wallet = BalanceRefreshWaitersTests.makeWallet(id: "waiters-wallet")
    private let siblingWallet = BalanceRefreshWaitersTests.makeWallet(id: "waiters-sibling")

    func test_settlingAWalletReportsItsResultToTheWaiter() async {
        let waiters = BalanceRefreshWaiters()

        let wait = await startWait(on: waiters, wallet: wallet)
        waiters.settle(wallet, result: .failed)

        let result = await wait.value
        XCTAssertEqual(result, .failed)
        XCTAssertTrue(waiters.isEmpty)
    }

    func test_everyWaiterOnTheSameWalletIsSettledWithTheSameResult() async {
        let waiters = BalanceRefreshWaiters()

        let first = await startWait(on: waiters, wallet: wallet)
        let second = await startWait(on: waiters, wallet: wallet)
        waiters.settle(wallet, result: .delivered(Self.balanceState))

        let firstResult = await first.value
        let secondResult = await second.value
        XCTAssertEqual(firstResult, .delivered(Self.balanceState))
        XCTAssertEqual(secondResult, .delivered(Self.balanceState))
        XCTAssertTrue(waiters.isEmpty)
    }

    func test_settlingOneWalletLeavesAnotherWalletWaiting() async {
        let waiters = BalanceRefreshWaiters()

        let wait = await startWait(on: waiters, wallet: wallet)
        waiters.settle(siblingWallet, result: .failed)

        XCTAssertFalse(waiters.isEmpty)

        waiters.settle(wallet, result: .failed)
        let result = await wait.value
        XCTAssertEqual(result, .failed)
    }

    func test_settlingEverythingRetiresWaitsOnEveryWallet() async {
        let waiters = BalanceRefreshWaiters()

        let first = await startWait(on: waiters, wallet: wallet)
        let second = await startWait(on: waiters, wallet: siblingWallet)
        waiters.settleAll(result: .dropped)

        let firstResult = await first.value
        let secondResult = await second.value
        XCTAssertEqual(firstResult, .dropped)
        XCTAssertEqual(secondResult, .dropped)
        XCTAssertTrue(waiters.isEmpty)
    }

    func test_retiringAWaitReportsNoAnswerToIt() async {
        let waiters = BalanceRefreshWaiters()
        let id = waiters.reserve()

        let wait = await startWait(on: waiters, wallet: wallet, id: id)
        waiters.retire(id)

        let result = await wait.value
        XCTAssertEqual(result, .dropped)
        XCTAssertTrue(waiters.isEmpty)
    }

    /// The cancellation handler can run before the continuation is installed, and the wait it
    /// retires must not be able to register behind it.
    func test_aWaitRetiredBeforeRegistrationIsRefused() async {
        let waiters = BalanceRefreshWaiters()
        let id = waiters.reserve()
        waiters.retire(id)

        let result = await withCheckedContinuation { (continuation: CheckedContinuation<BalanceRefreshResult, Never>) in
            guard waiters.register(id, wallet: wallet, continuation: continuation) else {
                return continuation.resume(returning: .dropped)
            }
            XCTFail("A retired wait must not be registered")
            continuation.resume(returning: .failed)
        }

        XCTAssertEqual(result, .dropped)
        XCTAssertTrue(waiters.isEmpty)
    }

    /// Asked when a run ends with nothing queued behind it, to tell a wait that run never answered
    /// from the usual case of none being left.
    func test_aWalletCarryingAWaitIsToldApartFromOneWithout() async {
        let waiters = BalanceRefreshWaiters()

        let wait = await startWait(on: waiters, wallet: wallet)

        XCTAssertTrue(waiters.hasWaiters(for: wallet))
        XCTAssertFalse(waiters.hasWaiters(for: siblingWallet))

        waiters.settle(wallet, result: .failed)
        _ = await wait.value

        XCTAssertFalse(waiters.hasWaiters(for: wallet))
    }

    func test_aWaitThatHasOnlyReservedItsPlaceDoesNotCount() {
        let waiters = BalanceRefreshWaiters()

        _ = waiters.reserve()

        XCTAssertFalse(waiters.hasWaiters(for: wallet))
    }

    func test_settlingWithNoWaitersDoesNothing() {
        let waiters = BalanceRefreshWaiters()

        waiters.settle(wallet, result: .failed)
        waiters.settleAll(result: .dropped)

        XCTAssertTrue(waiters.isEmpty)
    }

    private func startWait(
        on waiters: BalanceRefreshWaiters,
        wallet: Wallet,
        id: UInt64? = nil
    ) async -> Task<BalanceRefreshResult, Never> {
        let id = id ?? waiters.reserve()
        let registered = expectation(description: "wait registered")
        let task = Task {
            await withCheckedContinuation { (continuation: CheckedContinuation<BalanceRefreshResult, Never>) in
                guard waiters.register(id, wallet: wallet, continuation: continuation) else {
                    registered.fulfill()
                    return continuation.resume(returning: .dropped)
                }
                registered.fulfill()
            }
        }
        await fulfillment(of: [registered], timeout: 1)
        return task
    }

    private static let balanceState = WalletBalanceState.current(
        WalletBalance(
            date: Date(timeIntervalSince1970: 0),
            balance: Balance(tonBalance: TonBalance(amount: 0), jettonsBalance: []),
            stacking: [],
            batteryBalance: nil,
            tronBalance: nil
        )
    )

    private static func makeWallet(id: String) -> Wallet {
        Wallet(
            id: id,
            identity: WalletIdentity(
                network: .mainnet,
                kind: .Regular(PublicKey(data: Data((id + String(repeating: "0", count: 32)).utf8).prefix(32)), .v5R1)
            ),
            metaData: WalletMetaData(label: id, tintColor: .SteelGray, icon: .icon(.wallet)),
            setupSettings: WalletSetupSettings(),
            batterySettings: BatterySettings()
        )
    }
}
