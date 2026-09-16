import Foundation

/// Paces an operation: every run is at least `minInterval` apart, and the interval belongs to the
/// request that asks for it, so a person waiting on the screen is held to a shorter floor than the
/// background traffic. A request that cannot start now rides the run already queued instead of
/// replacing the one in flight.
final class BalanceRefreshThrottle {
    typealias Sleep = @Sendable (TimeInterval) async throws -> Void

    enum Decision: Equatable {
        case start
        /// A run that started before this request may have read the backend before the change it
        /// reports was indexed, so it earns exactly one follow-up. A request that only wants the
        /// value that run is already fetching rides it instead and is answered by it.
        case coalesce
        case schedule(after: TimeInterval)
        case skip
    }

    /// Both cases carry the priority that queued them: it picks the interval applied when they
    /// finally get their turn, and a higher one landing on a queued lower one promotes it.
    private enum Pending {
        case afterCurrentRun(priority: BalanceRefreshPriority)
        /// Carries when it will wake, because the interval it was computed from can shrink under it.
        case scheduled(wake: Date, priority: BalanceRefreshPriority)

        var scheduledWake: Date? {
            switch self {
            case let .scheduled(wake, _):
                wake
            default:
                nil
            }
        }

        var isFollowUpPending: Bool {
            switch self {
            case .afterCurrentRun:
                true
            default:
                false
            }
        }
    }

    /// What a finished run leaves behind, since only one of the four cases has anything left to do.
    private enum RunOutcome {
        /// A newer run owns the throttle, so the one reporting speaks for nobody.
        case retired
        case followUp(priority: BalanceRefreshPriority)
        /// A wait is already queued, so it answers whoever this run did not.
        case queued
        case idle
    }

    /// The run is over and nothing is queued behind it. A request that rode that run and registered
    /// its wait while it was already settling was answered by nobody, and this is where the run
    /// that answers it can be started.
    var onIdle: (() -> Void)?

    /// Read per request: the interval depends on the priority and on the reload mode, and both
    /// change under us.
    private let minInterval: @Sendable (BalanceRefreshPriority) -> TimeInterval
    private let now: @Sendable () -> Date
    private let sleep: Sleep
    private let operation: (Int) async -> Void

    private let lock = NSLock()
    private var isRunning = false
    private var pending: Pending?
    private var lastRunDate: Date?
    private var runningTask: Task<Void, Never>?
    private var scheduledTask: Task<Void, Never>?
    /// Bumped by `cancel`. A cancelled run still reaches its completion — its awaits may not observe
    /// cancellation at all — and without this it would report the state of the run that replaced it.
    private var generation = 0

    init(
        minInterval: @escaping @Sendable (BalanceRefreshPriority) -> TimeInterval,
        now: @escaping @Sendable () -> Date = { Date() },
        sleep: @escaping Sleep = BalanceRefreshThrottle.defaultSleep,
        operation: @escaping (Int) async -> Void
    ) {
        self.minInterval = minInterval
        self.now = now
        self.sleep = sleep
        self.operation = operation
    }
}

extension BalanceRefreshThrottle {
    /// The task is created under the same lock as the decision that spawns it, so `cancel` can
    /// never run in between and leave a started run with nothing to cancel.
    func request(priority: BalanceRefreshPriority) {
        lock.withLock {
            let now = now()
            switch Self.decision(
                isRunning: isRunning,
                isFollowUpPending: pending?.isFollowUpPending == true,
                earnsFollowUp: priority.earnsFollowUpRun,
                scheduledWake: pending?.scheduledWake,
                lastRunDate: lastRunDate,
                now: now,
                minInterval: minInterval(priority)
            ) {
            case .start:
                // Reachable with a wait still queued, now that a shrunk interval can overtake it.
                // That wait is moot — this request is starting the run it was queued for.
                if let replaced = scheduledTask {
                    generation &+= 1
                    scheduledTask = nil
                    replaced.cancel()
                }
                pending = nil
                isRunning = true
                lastRunDate = now
                let generation = generation
                runningTask = Task { [weak self] in
                    await self?.operation(generation)
                    self?.finishRun(generation: generation)
                }
            case .coalesce:
                pending = .afterCurrentRun(priority: priority)
            case let .schedule(delay):
                // Replaces any wait already queued, so the shorter interval wins rather than
                // queueing beside it. The bumped generation retires the task being replaced.
                let replaced = scheduledTask
                generation &+= 1
                pending = .scheduled(wake: now.addingTimeInterval(delay), priority: priority)
                let generation = generation
                replaced?.cancel()
                scheduledTask = Task { [weak self] in
                    guard let self else { return }
                    do {
                        try await sleep(delay)
                    } catch {
                        return
                    }
                    guard let priority = consumeScheduled(generation: generation) else { return }
                    request(priority: priority)
                }
            case .skip:
                promotePending(to: priority)
            }
        }
    }

    /// Nothing is running and nothing is queued, so nothing is going to answer a request that rode
    /// a run instead of starting one.
    var isIdle: Bool {
        lock.withLock { !isRunning && pending == nil }
    }

    /// A cancelled run still reaches its completion — its awaits may not observe the cancellation
    /// at all — so it has to be able to tell that what it learned belongs to nobody.
    func isRunCurrent(_ generation: Int) -> Bool {
        lock.withLock { generation == self.generation }
    }

    /// Drops the queued run and the one in flight.
    func cancel() {
        let (running, scheduled) = lock.withLock { () -> (Task<Void, Never>?, Task<Void, Never>?) in
            let running = runningTask
            let scheduled = scheduledTask
            generation &+= 1
            isRunning = false
            pending = nil
            runningTask = nil
            scheduledTask = nil
            return (running, scheduled)
        }
        running?.cancel()
        scheduled?.cancel()
    }

    private func finishRun(generation: Int) {
        let outcome = lock.withLock { () -> RunOutcome in
            guard generation == self.generation else { return .retired }
            isRunning = false
            runningTask = nil
            switch pending {
            case let .afterCurrentRun(priority):
                pending = nil
                return .followUp(priority: priority)
            case .scheduled:
                return .queued
            case nil:
                return .idle
            }
        }
        switch outcome {
        case .retired, .queued:
            break
        case let .followUp(priority):
            request(priority: priority)
        case .idle:
            onIdle?()
        }
    }

    private func consumeScheduled(generation: Int) -> BalanceRefreshPriority? {
        lock.withLock {
            guard generation == self.generation, case let .scheduled(_, priority) = pending else {
                return nil
            }
            pending = nil
            scheduledTask = nil
            return priority
        }
    }

    /// A request someone is waiting on hands its shorter floor to the background one it landed
    /// behind, rather than being paced by it.
    private func promotePending(to priority: BalanceRefreshPriority) {
        guard priority > .background, case .afterCurrentRun(.background) = pending else { return }
        pending = .afterCurrentRun(priority: priority)
    }
}

extension BalanceRefreshThrottle {
    static func decision(
        isRunning: Bool,
        isFollowUpPending: Bool,
        earnsFollowUp: Bool,
        scheduledWake: Date?,
        lastRunDate: Date?,
        now: Date,
        minInterval: TimeInterval
    ) -> Decision {
        if isFollowUpPending {
            return .skip
        }
        if isRunning {
            return earnsFollowUp ? .coalesce : .skip
        }
        let remaining = lastRunDate.map {
            minInterval - now.timeIntervalSince($0)
        } ?? 0
        guard remaining > 0 else {
            return .start
        }
        // A queued run covers this request — unless the mode changed under it and the interval it
        // was scheduled on is no longer the one that applies. Entering a hot window is exactly that.
        if let scheduledWake, scheduledWake <= now.addingTimeInterval(remaining) {
            return .skip
        }
        return .schedule(after: remaining)
    }

    static let defaultSleep: Sleep = { delay in
        try await Task.sleep(nanoseconds: UInt64(max(0, delay) * 1_000_000_000))
    }

    convenience init(
        minInterval: TimeInterval,
        now: @escaping @Sendable () -> Date = { Date() },
        sleep: @escaping Sleep = BalanceRefreshThrottle.defaultSleep,
        operation: @escaping (Int) async -> Void
    ) {
        self.init(minInterval: { _ in minInterval }, now: now, sleep: sleep, operation: operation)
    }
}
