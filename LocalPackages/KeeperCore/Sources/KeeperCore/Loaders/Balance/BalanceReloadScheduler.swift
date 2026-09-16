import Foundation

enum BalanceLoaderMode: Equatable {
    /// Just after the user moved funds: poll at the fast interval until the window expires.
    case hot
    case regular
    /// Someone needs the request budget: no periodic reload, and automatic refreshes are ignored.
    case quiet
}

/// Silence is held per owner rather than as a flag, so releasing one owner cannot speak for
/// another: `id` keeps two concurrent flows from sharing a single slot.
public enum BalanceQuietOwner: Hashable {
    case appLifecycle
    case flow(id: String)

    /// The lowest priority this owner still lets through while it holds silence. The app-lifecycle
    /// owner releases on `didBecomeActive`, strictly later than the foreground edge a screen reacts
    /// to, so a load answering that edge must not be held by it.
    var admits: BalanceRefreshPriority {
        switch self {
        case .appLifecycle: .userVisible
        case .flow: .userInitiated
        }
    }
}

/// Owns the periodic reload: which interval applies right now, and the task that ticks on it.
///
/// Releasing silence deliberately does not close an open hot window: handing the budget back says
/// "stop being quiet", not "stop being interested".
final class BalanceReloadScheduler {
    typealias Sleep = @Sendable (TimeInterval) async throws -> Void

    var onTick: (() -> Void)? {
        get { lock.withLock { tickHandler } }
        set { lock.withLock { tickHandler = newValue } }
    }

    var mode: BalanceLoaderMode {
        lock.withLock { currentMode() }
    }

    func admits(_ priority: BalanceRefreshPriority) -> Bool {
        lock.withLock { quietOwners.allSatisfy { priority >= $0.admits } }
    }

    private let hotInterval: TimeInterval
    private let regularInterval: TimeInterval
    private let hotDuration: TimeInterval
    private let now: @Sendable () -> Date
    private let sleep: Sleep

    private let lock = NSLock()
    /// Starts quiet: nothing should poll until the app says it is active.
    private var quietOwners: Set<BalanceQuietOwner> = [.appLifecycle]
    private var hotUntil: Date?
    private var regularPollingPaused = false
    private var task: Task<Void, Never>?
    private var tickHandler: (() -> Void)?

    init(
        hotInterval: TimeInterval,
        regularInterval: TimeInterval,
        hotDuration: TimeInterval,
        now: @escaping @Sendable () -> Date = { Date() },
        sleep: @escaping Sleep = BalanceReloadScheduler.defaultSleep
    ) {
        self.hotInterval = hotInterval
        self.regularInterval = regularInterval
        self.hotDuration = hotDuration
        self.now = now
        self.sleep = sleep
    }

    /// Extends the deadline, so asking twice is the same as asking once.
    func enterHotWindow() {
        applyChange { hotUntil = now().addingTimeInterval(hotDuration) }
    }

    func setQuiet(_ isQuiet: Bool, owner: BalanceQuietOwner) {
        applyChange {
            if isQuiet {
                quietOwners.insert(owner)
            } else {
                quietOwners.remove(owner)
            }
        }
    }

    func setRegularPollingPaused(_ paused: Bool) {
        applyChange { regularPollingPaused = paused }
    }

    private func applyChange(_ change: () -> Void) {
        let needsRestart = lock.withLock { () -> Bool in
            let before = currentInterval()
            change()
            let after = currentInterval()
            if after != before { return true }
            // The interval is derived, so a scheduler that has never ticked already reports the
            // regular one. Whether the loop is actually running is the other half of the answer.
            return (after == nil) != (task == nil)
        }
        // Extending an open hot window leaves the cadence alone, so a burst of events cannot keep
        // resetting the sleep and starve the tick.
        guard needsRestart else { return }
        restart()
    }

    func cancel() {
        let task = lock.withLock { () -> Task<Void, Never>? in
            let task = self.task
            self.task = nil
            return task
        }
        task?.cancel()
    }

    private func currentMode() -> BalanceLoaderMode {
        if !quietOwners.isEmpty { return .quiet }
        if let hotUntil, now() < hotUntil { return .hot }
        return .regular
    }

    private func currentInterval() -> TimeInterval? {
        switch currentMode() {
        case .quiet: nil
        case .hot: hotInterval
        case .regular: regularPollingPaused ? nil : regularInterval
        }
    }

    private func restart() {
        let previous = lock.withLock { () -> Task<Void, Never>? in
            let previous = task
            task = makeTickTask()
            return previous
        }
        previous?.cancel()
    }

    private func makeTickTask() -> Task<Void, Never>? {
        guard currentInterval() != nil else { return nil }
        return Task { [weak self] in
            while true {
                // Checked before reading the interval: a loop replaced before it first ran must not
                // start a sleep on the mode that replaced it.
                guard !Task.isCancelled else { return }
                guard let self, let interval = lock.withLock({ self.currentInterval() }) else { return }
                do {
                    try await sleep(interval)
                } catch {
                    return
                }
                guard !Task.isCancelled else { return }
                onTick?()
            }
        }
    }
}

extension BalanceReloadScheduler {
    static let defaultSleep: Sleep = { delay in
        try await Task.sleep(nanoseconds: UInt64(max(0, delay) * 1_000_000_000))
    }
}
