import QuartzCore
import UIKit

@MainActor
protocol ScreenRenderScheduling {
    var now: TimeInterval { get }
    func onNextFrame(_ action: @escaping @MainActor () -> Void)
    func after(_ delay: TimeInterval, _ action: @escaping @MainActor () -> Void)
}

/// Measures how long a screen takes to show content after the user action that opened it.
///
/// A session starts with `begin` and reports once. Calls for a screen with no active session are ignored,
/// so screens report their stages unconditionally. The first object that reports a lifecycle event owns the
/// session; lifecycle events and `abandon` from other instances of the screen are ignored, and so are stages
/// that name another owner.
@MainActor
public final class ScreenRenderTracker {
    public static let shared: ScreenRenderTracker = {
        let tracker = ScreenRenderTracker(scheduler: LiveScreenRenderScheduler())
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                ScreenRenderTracker.shared.appDidEnterBackground()
            }
        }
        return tracker
    }()

    public weak var reporter: ScreenRenderReporter?

    static let timeout: TimeInterval = 30
    static let launchLimit: TimeInterval = 60

    private let scheduler: ScreenRenderScheduling
    private var sessions: [ScreenRenderID: Session] = [:]
    private var launch: LaunchState? = LaunchState()

    init(scheduler: ScreenRenderScheduling) {
        self.scheduler = scheduler
    }

    public func begin(
        _ screen: ScreenRenderID,
        trigger: ScreenRenderTrigger,
        isFirstOpen: Bool
    ) {
        start(Session(screen: screen, trigger: trigger, isFirstOpen: isFirstOpen, start: scheduler.now))
    }

    /// A launch step before the cold-launch session starts; it is reported among that session's marks.
    public func launchMark(_ step: ScreenRenderLaunchStep) {
        guard let launch, !launch.marks.contains(where: { $0.name == step.rawValue }) else { return }
        launch.marks.append((step.rawValue, scheduler.now, launch.pausedTotal))
    }

    /// The launch waits for the user, e.g. on the passcode screen; the wait is left out of every later time.
    public func pauseLaunch() {
        guard let launch, launch.pauseStart == nil else { return }
        launch.pauseStart = scheduler.now
    }

    public func resumeLaunch() {
        guard let launch, let pauseStart = launch.pauseStart else { return }
        launch.pausedTotal += scheduler.now - pauseStart
        launch.pauseStart = nil
        launch.wasPaused = true
    }

    /// The launch does not end on the portfolio, e.g. it opens onboarding.
    public func cancelLaunch() {
        launch = nil
    }

    /// Starts the cold-launch portfolio session from the process start. Skipped when the launch was
    /// prewarmed, or when the app's own work took longer than `launchLimit`, e.g. after onboarding.
    public func beginLaunch(processStartTime: TimeInterval? = ScreenRenderTracker.processStartTime) {
        guard let launch else { return }
        self.launch = nil
        guard let processStartTime,
              scheduler.now - processStartTime - launch.pausedTotal < Self.launchLimit
        else { return }
        let session = Session(
            screen: .portfolio,
            trigger: .appLaunch,
            isFirstOpen: true,
            start: processStartTime,
            pausedTotal: launch.pausedTotal
        )
        session.hadPasscode = launch.wasPaused
        session.marks = launch.marks.map { mark in
            ScreenRenderMark(name: mark.name, ms: Session.milliseconds(mark.time - processStartTime - mark.pausedBefore))
        }
        start(session)
    }

    public func lifecycle(_ event: ScreenRenderLifecycle, for screen: ScreenRenderID, from owner: AnyObject) {
        guard let session = sessions[screen], session.claim(by: owner) else { return }
        let elapsed = session.elapsed(to: scheduler.now)
        switch event {
        case .viewDidLoad:
            session.viewDidLoadMs = session.viewDidLoadMs ?? elapsed
        case .viewWillAppear:
            session.willAppearMs = session.willAppearMs ?? elapsed
        case .viewDidAppear:
            session.didAppearMs = session.didAppearMs ?? elapsed
        }
    }

    /// Call right after the content is applied to the UI; the stage is timed at the next frame.
    public func contentApplied(_ stage: ScreenRenderStage, for screen: ScreenRenderID, from owner: AnyObject? = nil) {
        guard let session = session(for: screen, from: owner) else { return }
        switch stage {
        case .cached:
            guard session.cachedMs == nil, !session.isCachedPending, !session.isFreshPending else { return }
            session.isCachedPending = true
        case .fresh:
            guard !session.isFreshPending else { return }
            session.isFreshPending = true
        }
        scheduler.onNextFrame { [weak self, weak session] in
            guard let self, let session, sessions[session.screen] === session else { return }
            let elapsed = session.elapsed(to: scheduler.now)
            switch stage {
            case .cached:
                session.cachedMs = elapsed
            case .fresh:
                session.freshMs = elapsed
                finish(session, outcome: .fresh)
            }
        }
    }

    public func mark(_ name: ScreenRenderMarkName, for screen: ScreenRenderID, from owner: AnyObject? = nil) {
        guard let session = session(for: screen, from: owner),
              !session.marks.contains(where: { $0.name == name.rawValue })
        else { return }
        session.marks.append(ScreenRenderMark(name: name.rawValue, ms: session.elapsed(to: scheduler.now)))
    }

    public func requestStarted(for screen: ScreenRenderID, from owner: AnyObject? = nil) {
        guard let session = session(for: screen, from: owner), session.requestStart == nil else { return }
        session.requestStart = scheduler.now
    }

    public func requestFinished(for screen: ScreenRenderID, from owner: AnyObject? = nil) {
        guard let session = session(for: screen, from: owner), let requestStart = session.requestStart, session.requestMs == nil else {
            return
        }
        session.requestMs = Session.milliseconds(scheduler.now - requestStart)
    }

    /// Fresh content could not be loaded; `cached_ms` tells whether cached content was on screen.
    public func failed(_ screen: ScreenRenderID, error: ScreenRenderErrorKind, from owner: AnyObject? = nil) {
        endAtNextFrame(screen, owner: owner, outcome: .failed, errorKind: error)
    }

    /// The screen shows content that needs no refresh, e.g. a tab reopened after it already loaded.
    public func finish(_ screen: ScreenRenderID, from owner: AnyObject? = nil) {
        endAtNextFrame(screen, owner: owner, outcome: .cachedOnly, errorKind: nil)
    }

    /// The screen went away before fresh content. Only the owner can abandon: a screen going away before the
    /// new one claims the session is the previous instance; a session nobody claims ends by timeout.
    public func abandon(_ screen: ScreenRenderID, by owner: AnyObject) {
        guard let session = sessions[screen], let sessionOwner = session.owner, sessionOwner === owner else { return }
        finish(session, outcome: .abandoned)
    }

    /// Time in the background is not render time, so every session and the pending launch end here.
    func appDidEnterBackground() {
        launch = nil
        for session in Array(sessions.values) {
            finish(session, outcome: .abandoned)
        }
    }

    func isActive(_ screen: ScreenRenderID) -> Bool {
        sessions[screen] != nil
    }
}

private extension ScreenRenderTracker {
    func start(_ session: Session) {
        if let previous = sessions[session.screen] {
            finish(previous, outcome: .abandoned)
        }
        sessions[session.screen] = session
        scheduler.after(Self.timeout) { [weak self, weak session] in
            guard let self, let session else { return }
            finish(session, outcome: .timeout)
        }
    }

    /// Stages from a screen that can have several instances name their owner; only the owner's count.
    func session(for screen: ScreenRenderID, from owner: AnyObject?) -> Session? {
        guard let session = sessions[screen] else { return nil }
        guard let owner else { return session }
        guard let sessionOwner = session.owner, sessionOwner === owner else { return nil }
        return session
    }

    /// Deferred so a cached stage applied in the same pass is timed first.
    func endAtNextFrame(
        _ screen: ScreenRenderID,
        owner: AnyObject?,
        outcome: ScreenRenderOutcome,
        errorKind: ScreenRenderErrorKind?
    ) {
        guard let session = session(for: screen, from: owner) else { return }
        scheduler.onNextFrame { [weak self, weak session] in
            guard let self, let session else { return }
            finish(session, outcome: outcome, errorKind: errorKind)
        }
    }

    func finish(_ session: Session, outcome: ScreenRenderOutcome, errorKind: ScreenRenderErrorKind? = nil) {
        guard sessions[session.screen] === session else { return }
        sessions[session.screen] = nil
        reporter?.report(
            ScreenRenderReport(
                screen: session.screen,
                trigger: session.trigger,
                outcome: outcome,
                isFirstOpen: session.isFirstOpen,
                cachedMs: session.cachedMs,
                freshMs: session.freshMs,
                viewDidLoadMs: session.viewDidLoadMs,
                willAppearMs: session.willAppearMs,
                didAppearMs: session.didAppearMs,
                requestMs: session.requestMs,
                errorKind: errorKind,
                pausedMs: session.pausedTotal > 0 ? Session.milliseconds(session.pausedTotal) : nil,
                hadPasscode: session.hadPasscode,
                marks: session.marks
            )
        )
    }
}

@MainActor
private final class Session {
    let screen: ScreenRenderID
    let trigger: ScreenRenderTrigger
    let isFirstOpen: Bool
    let start: TimeInterval
    let pausedTotal: TimeInterval

    private(set) weak var owner: AnyObject?
    private var isClaimed = false
    var hadPasscode: Bool?
    var cachedMs: Int64?
    var freshMs: Int64?
    var isCachedPending = false
    var isFreshPending = false
    var viewDidLoadMs: Int64?
    var willAppearMs: Int64?
    var didAppearMs: Int64?
    var requestStart: TimeInterval?
    var requestMs: Int64?
    var marks: [ScreenRenderMark] = []

    init(
        screen: ScreenRenderID,
        trigger: ScreenRenderTrigger,
        isFirstOpen: Bool,
        start: TimeInterval,
        pausedTotal: TimeInterval = 0
    ) {
        self.screen = screen
        self.trigger = trigger
        self.isFirstOpen = isFirstOpen
        self.start = start
        self.pausedTotal = pausedTotal
    }

    /// The first caller owns the session; an owner that has gone away keeps it from being claimed again.
    func claim(by candidate: AnyObject) -> Bool {
        guard isClaimed else {
            isClaimed = true
            owner = candidate
            return true
        }
        return owner === candidate
    }

    /// The launch pause ends before the session starts, so every stage comes after all of it.
    func elapsed(to time: TimeInterval) -> Int64 {
        Self.milliseconds(time - start - pausedTotal)
    }

    static func milliseconds(_ interval: TimeInterval) -> Int64 {
        Int64((max(interval, 0) * 1000).rounded())
    }
}

@MainActor
private final class LaunchState {
    var marks: [(name: String, time: TimeInterval, pausedBefore: TimeInterval)] = []
    var pauseStart: TimeInterval?
    var pausedTotal: TimeInterval = 0
    var wasPaused = false
}

@MainActor
private final class LiveScreenRenderScheduler: ScreenRenderScheduling {
    private let nextFrame = NextFrameQueue()

    var now: TimeInterval {
        CACurrentMediaTime()
    }

    func onNextFrame(_ action: @escaping @MainActor () -> Void) {
        nextFrame.enqueue(action)
    }

    func after(_ delay: TimeInterval, _ action: @escaping @MainActor () -> Void) {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            action()
        }
    }
}

/// One display link runs every action queued for the next frame in the order it was queued; stages rely on
/// that order, e.g. a cached stage queued before `finish` is timed before the session ends.
@MainActor
private final class NextFrameQueue: NSObject {
    private var actions: [@MainActor () -> Void] = []
    private var displayLink: CADisplayLink?

    func enqueue(_ action: @escaping @MainActor () -> Void) {
        actions.append(action)
        guard displayLink == nil else { return }
        let displayLink = CADisplayLink(target: self, selector: #selector(fire))
        displayLink.add(to: .main, forMode: .common)
        self.displayLink = displayLink
    }

    @objc private func fire() {
        displayLink?.invalidate()
        displayLink = nil
        let actions = actions
        self.actions = []
        actions.forEach { $0() }
    }
}
