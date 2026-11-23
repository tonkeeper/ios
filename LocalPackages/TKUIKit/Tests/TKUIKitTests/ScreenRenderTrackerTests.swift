@testable import TKUIKit
import XCTest

@MainActor
private final class ManualScheduler: ScreenRenderScheduling {
    var now: TimeInterval = 100
    private var frameActions: [@MainActor () -> Void] = []
    private var delayedActions: [(fireAt: TimeInterval, action: @MainActor () -> Void)] = []

    func onNextFrame(_ action: @escaping @MainActor () -> Void) {
        frameActions.append(action)
    }

    func after(_ delay: TimeInterval, _ action: @escaping @MainActor () -> Void) {
        delayedActions.append((now + delay, action))
    }

    func advance(by interval: TimeInterval) {
        now += interval
        let due = delayedActions.filter { $0.fireAt <= now }
        delayedActions.removeAll { $0.fireAt <= now }
        due.forEach { $0.action() }
    }

    func renderFrame(after interval: TimeInterval = 0) {
        now += interval
        let actions = frameActions
        frameActions = []
        actions.forEach { $0() }
    }
}

@MainActor
private final class RecordingReporter: ScreenRenderReporter {
    var reports: [ScreenRenderReport] = []

    func report(_ report: ScreenRenderReport) {
        reports.append(report)
    }
}

@MainActor
final class ScreenRenderTrackerTests: XCTestCase {
    private var scheduler: ManualScheduler!
    private var reporter: RecordingReporter!
    private var tracker: ScreenRenderTracker!
    private let owner = NSObject()

    override func setUp() {
        super.setUp()
        scheduler = ManualScheduler()
        reporter = RecordingReporter()
        tracker = ScreenRenderTracker(scheduler: scheduler)
        tracker.reporter = reporter
    }

    override func tearDown() {
        tracker = nil
        reporter = nil
        scheduler = nil
        super.tearDown()
    }

    func testCachedThenFreshReportsBothStagesAtTheirFrames() {
        tracker.begin(.portfolio, trigger: .inApp, isFirstOpen: true)
        scheduler.advance(by: 0.010)
        tracker.lifecycle(.viewDidLoad, for: .portfolio, from: owner)
        tracker.contentApplied(.cached, for: .portfolio)
        scheduler.renderFrame(after: 0.016)
        tracker.requestStarted(for: .portfolio)
        scheduler.advance(by: 0.300)
        tracker.requestFinished(for: .portfolio)
        tracker.mark(ScreenRenderMarkName("total_fresh"), for: .portfolio)
        tracker.contentApplied(.fresh, for: .portfolio)
        scheduler.renderFrame(after: 0.016)

        XCTAssertEqual(reporter.reports, [
            ScreenRenderReport(
                screen: .portfolio,
                trigger: .inApp,
                outcome: .fresh,
                isFirstOpen: true,
                cachedMs: 26,
                freshMs: 342,
                viewDidLoadMs: 10,
                willAppearMs: nil,
                didAppearMs: nil,
                requestMs: 300,
                errorKind: nil,
                pausedMs: nil,
                hadPasscode: nil,
                marks: [ScreenRenderMark(name: "total_fresh", ms: 326)]
            ),
        ])
        XCTAssertFalse(tracker.isActive(.portfolio))
    }

    func testFreshWithoutCacheLeavesCachedEmpty() {
        tracker.begin(.history, trigger: .inApp, isFirstOpen: true)
        tracker.contentApplied(.fresh, for: .history)
        scheduler.renderFrame(after: 0.2)

        XCTAssertEqual(reporter.reports.first?.outcome, .fresh)
        XCTAssertNil(reporter.reports.first?.cachedMs)
        XCTAssertEqual(reporter.reports.first?.freshMs, 200)
    }

    func testFailureAfterCachedKeepsTheCachedStage() {
        tracker.begin(.trade, trigger: .inApp, isFirstOpen: false)
        tracker.contentApplied(.cached, for: .trade)
        tracker.failed(.trade, error: .server)
        scheduler.renderFrame(after: 0.05)

        XCTAssertEqual(reporter.reports.map(\.outcome), [.failed])
        XCTAssertEqual(reporter.reports.first?.errorKind, .server)
        XCTAssertEqual(reporter.reports.first?.cachedMs, 50)
    }

    func testFailureWithoutContentReportsFailed() {
        tracker.begin(.browser, trigger: .inApp, isFirstOpen: true)
        tracker.failed(.browser, error: .offline)
        scheduler.renderFrame()

        XCTAssertEqual(reporter.reports.map(\.outcome), [.failed])
        XCTAssertEqual(reporter.reports.first?.errorKind, .offline)
        XCTAssertNil(reporter.reports.first?.cachedMs)
    }

    func testFinishReportsCachedOnlyWithoutError() {
        tracker.begin(.trade, trigger: .inApp, isFirstOpen: false)
        tracker.contentApplied(.cached, for: .trade)
        tracker.finish(.trade)
        scheduler.renderFrame()

        XCTAssertEqual(reporter.reports.map(\.outcome), [.cachedOnly])
        XCTAssertNil(reporter.reports.first?.errorKind)
    }

    func testSecondBeginAbandonsThePreviousSession() {
        tracker.begin(.trade, trigger: .inApp, isFirstOpen: true)
        tracker.contentApplied(.fresh, for: .trade)
        tracker.begin(.trade, trigger: .deeplink, isFirstOpen: false)
        scheduler.renderFrame()

        XCTAssertEqual(reporter.reports.map(\.outcome), [.abandoned])
        XCTAssertNil(reporter.reports.first?.freshMs)
        XCTAssertTrue(tracker.isActive(.trade))
    }

    func testTimeoutEndsAnUnfinishedSession() {
        tracker.begin(.portfolio, trigger: .appLaunch, isFirstOpen: true)
        scheduler.advance(by: ScreenRenderTracker.timeout)

        XCTAssertEqual(reporter.reports.map(\.outcome), [.timeout])
        XCTAssertFalse(tracker.isActive(.portfolio))
    }

    func testTimeoutOfAFinishedSessionDoesNotReportAgain() {
        tracker.begin(.portfolio, trigger: .inApp, isFirstOpen: true)
        tracker.contentApplied(.fresh, for: .portfolio)
        scheduler.renderFrame()
        tracker.begin(.portfolio, trigger: .inApp, isFirstOpen: false)
        scheduler.advance(by: ScreenRenderTracker.timeout)

        XCTAssertEqual(reporter.reports.map(\.outcome), [.fresh, .timeout])
        XCTAssertEqual(reporter.reports.map(\.isFirstOpen), [true, false])
    }

    func testCallsWithoutSessionAreIgnored() {
        tracker.lifecycle(.viewDidLoad, for: .browser, from: owner)
        tracker.contentApplied(.cached, for: .browser)
        tracker.contentApplied(.fresh, for: .browser)
        tracker.mark(ScreenRenderMarkName("x"), for: .browser)
        tracker.failed(.browser, error: .network)
        tracker.abandon(.browser, by: owner)
        scheduler.renderFrame()

        XCTAssertTrue(reporter.reports.isEmpty)
    }

    func testCachedAfterFreshIsIgnored() {
        tracker.begin(.history, trigger: .inApp, isFirstOpen: true)
        tracker.contentApplied(.fresh, for: .history)
        tracker.contentApplied(.cached, for: .history)
        scheduler.renderFrame()

        XCTAssertEqual(reporter.reports.map(\.outcome), [.fresh])
        XCTAssertNil(reporter.reports.first?.cachedMs)
    }

    func testOnlyFirstOccurrencesAreKept() {
        tracker.begin(.trade, trigger: .inApp, isFirstOpen: true)
        scheduler.advance(by: 0.01)
        tracker.lifecycle(.viewWillAppear, for: .trade, from: owner)
        tracker.mark(ScreenRenderMarkName("favorites"), for: .trade)
        tracker.requestStarted(for: .trade)
        scheduler.advance(by: 0.01)
        tracker.lifecycle(.viewWillAppear, for: .trade, from: owner)
        tracker.mark(ScreenRenderMarkName("favorites"), for: .trade)
        tracker.requestStarted(for: .trade)
        tracker.requestFinished(for: .trade)
        scheduler.advance(by: 0.01)
        tracker.requestFinished(for: .trade)
        tracker.abandon(.trade, by: owner)

        let report = reporter.reports.first
        XCTAssertEqual(report?.willAppearMs, 10)
        XCTAssertEqual(report?.marks, [ScreenRenderMark(name: "favorites", ms: 10)])
        XCTAssertEqual(report?.requestMs, 10)
    }

    func testSessionsOfDifferentScreensAreIndependent() {
        tracker.begin(.trade, trigger: .inApp, isFirstOpen: true)
        tracker.begin(.browser, trigger: .inApp, isFirstOpen: true)
        tracker.lifecycle(.viewDidLoad, for: .trade, from: owner)
        tracker.abandon(.trade, by: owner)

        XCTAssertEqual(reporter.reports.map(\.screen), [.trade])
        XCTAssertTrue(tracker.isActive(.browser))
    }

    func testAbandonFromAnotherInstanceOfTheScreenIsIgnored() {
        let coveredScreen = NSObject()
        tracker.begin(.history, trigger: .push, isFirstOpen: true)
        tracker.lifecycle(.viewDidLoad, for: .history, from: owner)
        tracker.abandon(.history, by: coveredScreen)

        XCTAssertTrue(tracker.isActive(.history))

        tracker.abandon(.history, by: owner)

        XCTAssertEqual(reporter.reports.map(\.outcome), [.abandoned])
    }

    func testLifecycleFromAnotherInstanceOfTheScreenIsIgnored() {
        let otherScreen = NSObject()
        tracker.begin(.history, trigger: .inApp, isFirstOpen: true)
        scheduler.advance(by: 0.01)
        tracker.lifecycle(.viewWillAppear, for: .history, from: owner)
        scheduler.advance(by: 0.01)
        tracker.lifecycle(.viewDidAppear, for: .history, from: otherScreen)
        tracker.abandon(.history, by: owner)

        XCTAssertEqual(reporter.reports.first?.willAppearMs, 10)
        XCTAssertNil(reporter.reports.first?.didAppearMs)
    }

    func testStagesFromAnotherInstanceOfTheScreenAreIgnored() {
        let previousScreen = NSObject()
        tracker.begin(.history, trigger: .push, isFirstOpen: true)
        tracker.lifecycle(.viewDidLoad, for: .history, from: owner)
        tracker.requestStarted(for: .history, from: previousScreen)
        tracker.contentApplied(.fresh, for: .history, from: previousScreen)
        tracker.failed(.history, error: .server, from: previousScreen)
        tracker.mark(ScreenRenderMarkName("stale"), for: .history, from: previousScreen)
        scheduler.renderFrame()

        XCTAssertTrue(reporter.reports.isEmpty)

        scheduler.advance(by: 0.1)
        tracker.contentApplied(.fresh, for: .history, from: owner)
        scheduler.renderFrame()

        XCTAssertEqual(reporter.reports.map(\.outcome), [.fresh])
        XCTAssertNil(reporter.reports.first?.requestMs)
        XCTAssertEqual(reporter.reports.first?.marks, [])
    }

    func testStagesNamingAnOwnerNeedAClaimedSession() {
        tracker.begin(.history, trigger: .push, isFirstOpen: true)
        tracker.contentApplied(.fresh, for: .history, from: owner)
        scheduler.renderFrame()

        XCTAssertTrue(reporter.reports.isEmpty)
        XCTAssertTrue(tracker.isActive(.history))
    }

    func testPreviousScreenGoingAwayKeepsAnUnclaimedSession() {
        let previousScreen = NSObject()
        tracker.begin(.history, trigger: .push, isFirstOpen: true)
        tracker.abandon(.history, by: previousScreen)
        tracker.lifecycle(.viewDidLoad, for: .history, from: owner)
        tracker.contentApplied(.fresh, for: .history)
        scheduler.renderFrame()

        XCTAssertEqual(reporter.reports.map(\.outcome), [.fresh])
    }

    func testUnclaimedSessionEndsByTimeout() {
        tracker.begin(.trade, trigger: .inApp, isFirstOpen: false)
        tracker.abandon(.trade, by: NSObject())
        scheduler.advance(by: ScreenRenderTracker.timeout)

        XCTAssertEqual(reporter.reports.map(\.outcome), [.timeout])
    }

    func testGoingToTheBackgroundAbandonsEverySessionAndTheLaunch() {
        tracker.begin(.trade, trigger: .inApp, isFirstOpen: true)
        tracker.begin(.history, trigger: .inApp, isFirstOpen: true)
        tracker.contentApplied(.fresh, for: .trade)
        tracker.appDidEnterBackground()
        scheduler.renderFrame(after: 120)
        tracker.beginLaunch(processStartTime: 99)

        XCTAssertEqual(Set(reporter.reports.map(\.screen)), [.trade, .history])
        XCTAssertEqual(reporter.reports.map(\.outcome), [.abandoned, .abandoned])
        XCTAssertFalse(tracker.isActive(.portfolio))
    }

    func testLaunchIsTimedFromTheProcessStartWithItsMarks() {
        tracker.launchMark(.didFinishLaunching)
        scheduler.advance(by: 0.5)
        tracker.launchMark(.rootStart)
        tracker.beginLaunch(processStartTime: 99)
        tracker.contentApplied(.fresh, for: .portfolio)
        scheduler.renderFrame(after: 0.5)

        let report = reporter.reports.first
        XCTAssertEqual(report?.trigger, .appLaunch)
        XCTAssertEqual(report?.freshMs, 2000)
        XCTAssertEqual(report?.marks, [
            ScreenRenderMark(name: "did_finish_launching", ms: 1000),
            ScreenRenderMark(name: "root_start", ms: 1500),
        ])
        XCTAssertEqual(report?.hadPasscode, false)
        XCTAssertNil(report?.pausedMs)
    }

    func testPasscodeWaitIsLeftOutOfLaterTimes() {
        tracker.launchMark(.passcodeShown)
        tracker.pauseLaunch()
        scheduler.advance(by: 5)
        tracker.resumeLaunch()
        tracker.launchMark(.passcodeEntered)
        scheduler.advance(by: 0.2)
        tracker.beginLaunch(processStartTime: 99)
        tracker.contentApplied(.fresh, for: .portfolio)
        scheduler.renderFrame(after: 0.3)

        let report = reporter.reports.first
        XCTAssertEqual(report?.marks, [
            ScreenRenderMark(name: "passcode_shown", ms: 1000),
            ScreenRenderMark(name: "passcode_entered", ms: 1000),
        ])
        XCTAssertEqual(report?.freshMs, 1500)
        XCTAssertEqual(report?.pausedMs, 5000)
        XCTAssertEqual(report?.hadPasscode, true)
    }

    func testLaunchBeginsOnceAndIgnoresLaterLaunchCalls() {
        tracker.beginLaunch(processStartTime: 99)
        tracker.lifecycle(.viewDidLoad, for: .portfolio, from: owner)
        tracker.abandon(.portfolio, by: owner)
        tracker.launchMark(.sceneConnect)
        tracker.pauseLaunch()
        scheduler.advance(by: 1)
        tracker.resumeLaunch()
        tracker.beginLaunch(processStartTime: 99)

        XCTAssertEqual(reporter.reports.count, 1)
        XCTAssertFalse(tracker.isActive(.portfolio))
    }

    func testLaunchLongerThanTheLimitIsSkipped() {
        tracker.beginLaunch(processStartTime: scheduler.now - ScreenRenderTracker.launchLimit - 1)

        XCTAssertFalse(tracker.isActive(.portfolio))
    }

    func testPasscodeWaitDoesNotCountTowardsTheLaunchLimit() {
        tracker.pauseLaunch()
        scheduler.advance(by: ScreenRenderTracker.launchLimit)
        tracker.resumeLaunch()
        tracker.beginLaunch(processStartTime: 99)

        XCTAssertTrue(tracker.isActive(.portfolio))
    }

    func testCancelledLaunchDoesNotBegin() {
        tracker.cancelLaunch()
        tracker.beginLaunch(processStartTime: 99)

        XCTAssertFalse(tracker.isActive(.portfolio))
    }

    func testPrewarmedLaunchIsSkipped() {
        tracker.beginLaunch(processStartTime: nil)

        XCTAssertFalse(tracker.isActive(.portfolio))
    }

    func testRegularSessionHasNoLaunchFields() {
        tracker.pauseLaunch()
        scheduler.advance(by: 1)
        tracker.resumeLaunch()
        tracker.begin(.trade, trigger: .inApp, isFirstOpen: true)
        tracker.contentApplied(.fresh, for: .trade)
        scheduler.renderFrame(after: 0.1)

        XCTAssertNil(reporter.reports.first?.hadPasscode)
        XCTAssertNil(reporter.reports.first?.pausedMs)
        XCTAssertEqual(reporter.reports.first?.freshMs, 100)
    }
}
