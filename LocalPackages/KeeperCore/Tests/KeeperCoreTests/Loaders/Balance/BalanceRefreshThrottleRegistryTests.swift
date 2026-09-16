import Foundation
@testable import KeeperCore
import TonSwift
import XCTest

final class BalanceRefreshThrottleRegistryTests: XCTestCase {
    private let wallet = BalanceRefreshThrottleRegistryTests.makeWallet(id: "wallet")
    private let siblingWallet = BalanceRefreshThrottleRegistryTests.makeWallet(id: "sibling")

    func test_aWalletKeepsTheThrottleItWasGiven() {
        let registry = makeRegistry()

        let first = registry.throttle(for: wallet)
        let second = registry.throttle(for: wallet)

        XCTAssertTrue(first === second, "a second request must ride the pacing of the first")
        XCTAssertFalse(first === registry.throttle(for: siblingWallet))
    }

    func test_theSweepIsPacedByOneThrottleOfItsOwn() {
        let registry = makeRegistry()

        XCTAssertTrue(registry.allWalletsThrottle() === registry.allWalletsThrottle())
        XCTAssertFalse(registry.allWalletsThrottle() === registry.throttle(for: wallet))
    }

    /// A run reports against the throttle that started it, so a wallet nobody has asked for must
    /// not have one conjured for the lookup.
    func test_aWalletNobodyHasAskedForHasNoThrottleToCheck() {
        let registry = makeRegistry()

        XCTAssertNil(registry.existingThrottle(for: wallet))

        let throttle = registry.throttle(for: wallet)

        XCTAssertTrue(registry.existingThrottle(for: wallet) === throttle)
    }

    func test_aRemovedWalletIsHandedBackItsThrottleAndForgotten() {
        let registry = makeRegistry()
        let throttle = registry.throttle(for: wallet)

        XCTAssertTrue(registry.remove(wallet: wallet) === throttle)
        XCTAssertNil(registry.existingThrottle(for: wallet))
        XCTAssertNil(registry.remove(wallet: wallet))
    }

    func test_cancellingReachesEveryThrottleIncludingTheSweep() async {
        let runs = ThrottleRuns()
        let registry = makeRegistry(runs: runs)

        registry.throttle(for: wallet).request(priority: .userInitiated)
        registry.throttle(for: siblingWallet).request(priority: .userInitiated)
        registry.allWalletsThrottle().request(priority: .userInitiated)
        await runs.awaitStarted(count: 3)

        registry.cancelAll()

        await runs.awaitCancelled(count: 3)
    }

    private func makeRegistry(runs: ThrottleRuns = ThrottleRuns()) -> BalanceRefreshThrottleRegistry {
        BalanceRefreshThrottleRegistry(
            makeWalletThrottle: { _ in
                BalanceRefreshThrottle(minInterval: 0, operation: { _ in await runs.perform() })
            },
            makeAllWalletsThrottle: {
                BalanceRefreshThrottle(minInterval: 0, operation: { _ in await runs.perform() })
            }
        )
    }

    private static func makeWallet(id: String) -> Wallet {
        let publicKeyData = Data((id + "-public-key").utf8) + Data(repeating: 0, count: 32)
        return Wallet(
            id: id,
            identity: WalletIdentity(
                network: .mainnet,
                kind: .Regular(TonSwift.PublicKey(data: Data(publicKeyData.prefix(32))), .v5R1)
            ),
            metaData: WalletMetaData(label: id, tintColor: .SteelGray, icon: .icon(.wallet)),
            setupSettings: WalletSetupSettings(),
            batterySettings: BatterySettings()
        )
    }
}

/// Parks every run until it is cancelled, so the test can tell what `cancelAll` actually reached.
private final class ThrottleRuns: @unchecked Sendable {
    private let lock = NSLock()
    private var started = 0
    private var cancelled = 0

    func perform() async {
        lock.withLock { started += 1 }
        await withTaskCancellationHandler {
            while !Task.isCancelled {
                await Task.yield()
            }
        } onCancel: {}
        lock.withLock { cancelled += 1 }
    }

    func awaitStarted(count: Int) async {
        await awaitCount(count) { lock.withLock { started } }
    }

    func awaitCancelled(count: Int) async {
        await awaitCount(count) { lock.withLock { cancelled } }
    }

    private func awaitCount(_ count: Int, _ read: () -> Int) async {
        while read() < count {
            await Task.yield()
        }
    }
}
