@testable import Perps
import PerpsModels
import TKTestSupport
import XCTest

private let untilCancelled = TestGate()

/// A change is fed to `apply` directly: the store observer only hops to the main actor before calling it.
@MainActor
final class PerpsWithdrawStatusViewModelTests: XCTestCase {
    func testAWithdrawalStartedHereGoesFromSendingToSentToConfirmed() {
        let model = makeModel(PerpsFundingActivity(inFlight: ["w"], withdrawals: ["w"]))
        XCTAssertEqual(model.status, .sending("w"))

        model.apply(PerpsFundingActivity(pending: ["w"], withdrawals: ["w"]))
        XCTAssertEqual(model.status, .sent("w"))

        model.apply(PerpsFundingActivity(completed: ["w"], withdrawals: ["w"]))
        XCTAssertEqual(model.status, .confirmed("w"))
    }

    func testAWithdrawalAcceptedBeforeTheScreenOpenedAnnouncesOnlyItsOutcome() {
        let model = makeModel(PerpsFundingActivity(pending: ["w"], withdrawals: ["w"]))
        XCTAssertNil(model.status)

        model.apply(PerpsFundingActivity(pending: ["w"], withdrawals: ["w"]))
        XCTAssertNil(model.status)

        model.apply(PerpsFundingActivity(failed: ["w"], withdrawals: ["w"]))
        XCTAssertEqual(model.status, .failed("w"))
    }

    func testOutcomesThatEndedBeforeTheScreenOpenedStayQuiet() {
        let model = makeModel(PerpsFundingActivity(completed: ["old"], failed: ["older"], withdrawals: ["old", "older"]))
        model.apply(PerpsFundingActivity(completed: ["old"], failed: ["older"], withdrawals: ["old", "older"]))

        XCTAssertNil(model.status)
    }

    func testAHiddenUnresolvedWithdrawalAnnouncesItsOutcomeAfterReopening() {
        let model = makeModel(PerpsFundingActivity(withdrawals: ["w"]))
        XCTAssertNil(model.status)

        model.apply(PerpsFundingActivity(failed: ["w"], withdrawals: ["w"]))

        XCTAssertEqual(model.status, .failed("w"))
    }

    func testAWithdrawalFirstSeenAlreadySettledIsAnnounced() {
        let model = makeModel(PerpsFundingActivity())

        model.apply(PerpsFundingActivity(completed: ["w"], withdrawals: ["w"]))

        XCTAssertEqual(model.status, .confirmed("w"))
    }

    func testAFailureWinsOverOtherWithdrawalsChangingAtTheSameTime() {
        let model = makeModel(PerpsFundingActivity())

        model.apply(PerpsFundingActivity(pending: ["c"], completed: ["b"], failed: ["a"], withdrawals: ["a", "b", "c"]))

        XCTAssertEqual(model.status, .failed("a"))
    }

    func testDepositsDoNotMoveThePill() {
        let model = makeModel(PerpsFundingActivity())

        model.apply(PerpsFundingActivity(inFlight: ["d"], completed: ["e"]))

        XCTAssertNil(model.status)
    }

    func testSendingEndsWithoutAnOutcomeWhenTheOperationIsGone() {
        let model = makeModel(PerpsFundingActivity(inFlight: ["w"], withdrawals: ["w"]))

        model.apply(PerpsFundingActivity())

        XCTAssertNil(model.status)
    }

    func testSentHidesOnceItsTimeIsUpAndTheSameStateDoesNotBringItBack() async {
        let lifetime = Gate()
        let model = makeModel(PerpsFundingActivity(), lifetime: lifetime)
        model.apply(PerpsFundingActivity(pending: ["w"], withdrawals: ["w"]))
        XCTAssertEqual(model.status, .sent("w"))

        await lifetime.waitUntilStarted(1)
        lifetime.open(0)
        await waitUntil(model) { model.status == nil }
        XCTAssertNil(model.status)

        model.apply(PerpsFundingActivity(pending: ["w"], withdrawals: ["w"]))
        XCTAssertNil(model.status)
    }

    func testANewStatusOutlivesThePreviousOnesTimer() async {
        let lifetime = Gate()
        let model = makeModel(PerpsFundingActivity(), lifetime: lifetime)
        model.apply(PerpsFundingActivity(pending: ["w"], withdrawals: ["w"]))
        await lifetime.waitUntilStarted(1)

        let previous = model.hideTask
        model.apply(PerpsFundingActivity(completed: ["w"], withdrawals: ["w"]))
        lifetime.open(0)
        await previous?.value

        XCTAssertEqual(model.status, .confirmed("w"))
        lifetime.openAll()
    }

    func testTapOpensTheWithdrawalInHistoryAndDismissesAFailure() {
        let model = makeModel(PerpsFundingActivity())
        var opened: [String] = []
        model.onOpenHistory = { opened.append($0) }

        model.apply(PerpsFundingActivity(pending: ["w"], withdrawals: ["w"]))
        model.tap()
        XCTAssertEqual(opened, ["w"])

        model.apply(PerpsFundingActivity(failed: ["w"], withdrawals: ["w"]))
        model.tap()
        XCTAssertEqual(opened, ["w"])
        XCTAssertNil(model.status)
    }

    private func makeModel(_ activity: PerpsFundingActivity, lifetime: Gate? = nil) -> PerpsWithdrawStatusViewModel {
        let store = StubRootAccountStore(activity: activity)
        guard let lifetime else {
            // Outlasts the test; a newer status or a hide cancels it.
            return PerpsWithdrawStatusViewModel(accountStore: store) { try? await untilCancelled.wait() }
        }
        return PerpsWithdrawStatusViewModel(accountStore: store) { await lifetime.wait() }
    }
}

/// Lifetimes the test ends by hand, in the order they started.
@MainActor
private final class Gate {
    private var waiters: [CheckedContinuation<Void, Never>?] = []
    private let started = TestSignal()

    func wait() async {
        await withCheckedContinuation {
            waiters.append($0)
            started.send()
        }
    }

    func waitUntilStarted(_ count: Int, file: StaticString = #filePath, line: UInt = #line) async {
        await waitUntil(started, file: file, line: line) { self.waiters.count >= count }
    }

    func open(_ index: Int) {
        waiters[index]?.resume()
        waiters[index] = nil
    }

    func openAll() {
        for index in waiters.indices {
            open(index)
        }
    }
}
