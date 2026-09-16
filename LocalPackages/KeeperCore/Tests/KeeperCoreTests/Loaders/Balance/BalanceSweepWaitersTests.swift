import Foundation
@testable import KeeperCore
import XCTest

final class BalanceSweepWaitersTests: XCTestCase {
    func test_everyWaiterIsAnsweredTogether() async {
        let waiters = BalanceSweepWaiters()

        let first = await startWait(on: waiters)
        let second = await startWait(on: waiters)
        waiters.resumeAll()

        await first.value
        await second.value
        XCTAssertTrue(waiters.isEmpty)
    }

    /// A sweep that finishes twice — its run ends and quiet drops what is left — must not resume a
    /// continuation that is already gone.
    func test_answeringTwiceLeavesNothingToResume() async {
        let waiters = BalanceSweepWaiters()

        let wait = await startWait(on: waiters)
        waiters.resumeAll()
        waiters.resumeAll()

        await wait.value
    }

    func test_answeringWithNoWaitersDoesNothing() {
        BalanceSweepWaiters().resumeAll()
    }

    /// The sweep the others are waiting on is still running, so a cancelled caller leaves on its
    /// own rather than reporting the end of it to everyone.
    func test_aRetiredWaitLeavesTheRestOnTheSweep() async {
        let waiters = BalanceSweepWaiters()
        let id = waiters.reserve()

        let retired = await startWait(on: waiters, id: id)
        let kept = await startWait(on: waiters)
        waiters.retire(id)

        await retired.value
        XCTAssertFalse(waiters.isEmpty)

        waiters.resumeAll()
        await kept.value
    }

    /// The cancellation handler can run before the continuation is installed, and the wait it
    /// retires must not be able to register behind it.
    func test_aWaitRetiredBeforeRegistrationIsRefused() async {
        let waiters = BalanceSweepWaiters()
        let id = waiters.reserve()
        waiters.retire(id)

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            guard waiters.register(id, continuation: continuation) else {
                return continuation.resume()
            }
            XCTFail("A retired wait must not be registered")
            continuation.resume()
        }

        XCTAssertTrue(waiters.isEmpty)
    }

    /// A wait that has only reserved its place has not asked the throttle for anything yet, so no
    /// sweep should be started on its behalf.
    func test_onlyAnInstalledWaitCountsAsWaiting() async {
        let waiters = BalanceSweepWaiters()

        _ = waiters.reserve()
        XCTAssertFalse(waiters.hasWaiters)

        let wait = await startWait(on: waiters)
        XCTAssertTrue(waiters.hasWaiters)

        waiters.resumeAll()
        await wait.value

        XCTAssertFalse(waiters.hasWaiters)
    }

    private func startWait(
        on waiters: BalanceSweepWaiters,
        id: UInt64? = nil
    ) async -> Task<Void, Never> {
        let id = id ?? waiters.reserve()
        let registered = expectation(description: "wait registered")
        let task = Task {
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                XCTAssertTrue(waiters.register(id, continuation: continuation))
                registered.fulfill()
            }
        }
        await fulfillment(of: [registered], timeout: 1)
        return task
    }
}
