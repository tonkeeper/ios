@testable import App
import Foundation
import KeeperCore
import XCTest

final class MultichainWalletSyncStatusPollingTests: XCTestCase {
    func test_trackerNotifiesForInitialStatus() {
        let current = makeStatus(status: .inProgress, backfill: .queued)
        var tracker = MultichainWalletSyncStatusPolling.Tracker()
        tracker.restart(walletIdentifier: "wallet")

        XCTAssertTrue(tracker.shouldNotify(current: current))
    }

    func test_trackerDoesNotNotifyWhenStatusIsUnchanged() {
        let status = makeStatus(status: .inProgress, backfill: .inProgress)
        var tracker = MultichainWalletSyncStatusPolling.Tracker()
        tracker.restart(walletIdentifier: "wallet")
        XCTAssertTrue(tracker.shouldNotify(current: status))

        XCTAssertFalse(tracker.shouldNotify(current: status))
    }

    func test_trackerNotifiesWhenStatusChanges() {
        let previous = makeStatus(status: .inProgress, backfill: .inProgress)
        let current = makeStatus(status: .ready, backfill: .complete)
        var tracker = MultichainWalletSyncStatusPolling.Tracker()
        tracker.restart(walletIdentifier: "wallet")
        XCTAssertTrue(tracker.shouldNotify(current: previous))

        XCTAssertTrue(tracker.shouldNotify(current: current))
    }

    func test_trackerDoesNotNotifyForFreshnessOrRetryChanges() {
        let previous = makeStatus(
            status: .inProgress,
            backfill: .inProgress,
            balancesAt: Date(timeIntervalSince1970: 1),
            activityAt: Date(timeIntervalSince1970: 2),
            retryAfterMilliseconds: 1000
        )
        let current = makeStatus(
            status: .inProgress,
            backfill: .inProgress,
            balancesAt: Date(timeIntervalSince1970: 3),
            activityAt: Date(timeIntervalSince1970: 4),
            retryAfterMilliseconds: 2000
        )
        var tracker = MultichainWalletSyncStatusPolling.Tracker()
        tracker.restart(walletIdentifier: "wallet")
        XCTAssertTrue(tracker.shouldNotify(current: previous))

        XCTAssertFalse(tracker.shouldNotify(current: current))
    }

    func test_trackerPreservesObservedStatusWhenSameWalletRestarts() {
        let initial = makeStatus(status: .inProgress, backfill: .queued)
        let observed = makeStatus(status: .inProgress, backfill: .inProgress)
        var tracker = MultichainWalletSyncStatusPolling.Tracker()
        tracker.restart(walletIdentifier: "wallet")
        XCTAssertTrue(tracker.shouldNotify(current: initial))
        XCTAssertTrue(tracker.shouldNotify(current: observed))

        tracker.restart(walletIdentifier: "wallet")

        XCTAssertFalse(tracker.shouldNotify(current: observed))
    }

    func test_trackerUsesNewWalletInitialStatus() {
        let first = makeStatus(status: .inProgress, backfill: .queued)
        let second = makeStatus(status: .ready, backfill: .complete)
        var tracker = MultichainWalletSyncStatusPolling.Tracker()
        tracker.restart(walletIdentifier: "first")
        XCTAssertTrue(tracker.shouldNotify(current: first))

        tracker.restart(walletIdentifier: "second")

        XCTAssertTrue(tracker.shouldNotify(current: second))
    }

    private func makeStatus(
        status: MultichainChainSyncStatus.Status,
        backfill: MultichainChainSyncStatus.Backfill,
        balancesAt: Date? = nil,
        activityAt: Date? = nil,
        retryAfterMilliseconds: Int? = nil
    ) -> MultichainWalletSyncStatus {
        MultichainWalletSyncStatus(chains: [
            .ton: MultichainChainSyncStatus(
                status: status,
                balancesAt: balancesAt,
                activityAt: activityAt,
                reason: nil,
                retryAfterMilliseconds: retryAfterMilliseconds,
                backfill: backfill
            ),
        ])
    }

    func test_replacementPreservesPollingRequirement() {
        var state = MultichainWalletAssetsReloadScheduling.State()
        let initial = state.makeRequest(startsSyncStatusPolling: true)

        let replacement = state.makeRequest(startsSyncStatusPolling: false)

        XCTAssertFalse(state.isCurrent(initial))
        XCTAssertTrue(state.isCurrent(replacement))
        XCTAssertTrue(state.consumePollingRequirement(for: replacement))
    }

    func test_consumedPollingRequirementDoesNotLeakIntoNextRequest() {
        var state = MultichainWalletAssetsReloadScheduling.State()
        let initial = state.makeRequest(startsSyncStatusPolling: true)
        XCTAssertTrue(state.consumePollingRequirement(for: initial))

        let next = state.makeRequest(startsSyncStatusPolling: false)

        XCTAssertFalse(state.consumePollingRequirement(for: next))
    }

    func test_cancellingCurrentRequestClearsPollingRequirement() {
        var state = MultichainWalletAssetsReloadScheduling.State()
        let cancelled = state.makeRequest(startsSyncStatusPolling: true)
        state.cancel(cancelled)

        let next = state.makeRequest(startsSyncStatusPolling: false)

        XCTAssertFalse(state.consumePollingRequirement(for: next))
    }
}
