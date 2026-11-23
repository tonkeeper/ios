import Foundation
import PerpsModels
import TKLogging

enum PerpsLiveTopic: Hashable, Sendable {
    case account
    case market(Int64)
    case anyMarket
    case deposit
    case withdrawal
}

final class PerpsLiveFeed: Sendable {
    static let slowInterval: TimeInterval = 30
    static let defaultDebounce: TimeInterval = 0.4

    private let hub: PerpsLiveHub

    init(signals: @escaping @Sendable () -> AsyncStream<PerpsRealtimeSignal>) {
        hub = PerpsLiveHub(signals: signals)
    }

    func listen(
        _ topics: Set<PerpsLiveTopic>,
        debounce: TimeInterval = PerpsLiveFeed.defaultDebounce,
        holdsSubscription: Bool = true
    ) async -> PerpsLiveListener {
        let id = UUID()
        await hub.add(id, topics: topics, debounce: debounce, holdsSubscription: holdsSubscription)
        return PerpsLiveListener(id: id, hub: hub)
    }

    func waits(on topics: Set<PerpsLiveTopic>) -> @Sendable (_ nanoseconds: UInt64) async -> Bool {
        let listener = Task { await listen(topics, holdsSubscription: false) }
        return { nanoseconds in
            let delay = TimeInterval(nanoseconds) / 1_000_000_000
            return await listener.value.next(pollAfter: delay, liveTimeout: max(delay, Self.slowInterval))
        }
    }
}

final class PerpsLiveListener: Sendable {
    private let id: UUID
    private let hub: PerpsLiveHub

    fileprivate init(id: UUID, hub: PerpsLiveHub) {
        self.id = id
        self.hub = hub
    }

    deinit {
        Task { [hub, id] in await hub.remove(id) }
    }

    @discardableResult
    func next(pollAfter: TimeInterval = PerpsLiveFeed.slowInterval, liveTimeout: TimeInterval? = nil) async -> Bool {
        let token = UUID()
        return await withTaskCancellationHandler {
            await hub.wait(id, token: token, pollAfter: pollAfter, liveTimeout: liveTimeout)
        } onCancel: { [hub, id] in
            Task { await hub.cancel(id, token: token) }
        }
    }
}

extension PerpsLiveListener: PerpsChanges {
    func next(orAfter interval: TimeInterval) async {
        await next(pollAfter: interval, liveTimeout: interval)
    }
}

private actor PerpsLiveHub {
    private struct Waiter {
        let token: UUID
        let continuation: CheckedContinuation<Bool, Never>
        let pollAfter: TimeInterval
        let liveTimeout: TimeInterval?
        var timer: Task<Void, Never>?
    }

    private struct Listener {
        let topics: Set<PerpsLiveTopic>
        let debounce: TimeInterval
        let holdsSubscription: Bool
        var pending = false
        var waiter: Waiter?
        var debounceTask: Task<Void, Never>?

        func matches(_ event: PerpsRealtimeEvent) -> Bool {
            switch event {
            case let .market(marketId): topics.contains(.market(marketId)) || topics.contains(.anyMarket)
            case .account: topics.contains(.account)
            case .deposit: topics.contains(.deposit)
            case .withdrawal: topics.contains(.withdrawal)
            }
        }
    }

    private let signals: @Sendable () -> AsyncStream<PerpsRealtimeSignal>
    private var listeners = [UUID: Listener]()
    private var isLive = false
    private var reader: Task<Void, Never>?
    private var readerId: UUID?

    init(signals: @escaping @Sendable () -> AsyncStream<PerpsRealtimeSignal>) {
        self.signals = signals
    }

    deinit {
        reader?.cancel()
    }

    func add(_ id: UUID, topics: Set<PerpsLiveTopic>, debounce: TimeInterval, holdsSubscription: Bool) {
        listeners[id] = Listener(topics: topics, debounce: debounce, holdsSubscription: holdsSubscription)
        guard holdsSubscription, reader == nil else { return }
        Log.perps.i("live feed: hold the channel")
        let stream = signals()
        let readerId = UUID()
        self.readerId = readerId
        reader = Task { [weak self] in
            for await signal in stream {
                await self?.handle(signal, from: readerId)
            }
            await self?.readerEnded(readerId)
        }
    }

    func remove(_ id: UUID) {
        guard let listener = listeners.removeValue(forKey: id) else { return }
        listener.debounceTask?.cancel()
        listener.waiter?.timer?.cancel()
        listener.waiter?.continuation.resume(returning: false)
        guard reader != nil, !listeners.values.contains(where: \.holdsSubscription) else { return }
        Log.perps.i("live feed: release the channel")
        reader?.cancel()
        reader = nil
        readerId = nil
        setLive(false)
    }

    func wait(_ id: UUID, token: UUID, pollAfter: TimeInterval, liveTimeout: TimeInterval?) async -> Bool {
        guard !Task.isCancelled, listeners[id] != nil else { return false }
        if listeners[id]?.pending == true {
            listeners[id]?.pending = false
            return true
        }
        if let stale = listeners[id]?.waiter {
            resume(id, token: stale.token, changed: false)
        }
        return await withCheckedContinuation { continuation in
            listeners[id]?.waiter = Waiter(token: token, continuation: continuation, pollAfter: pollAfter, liveTimeout: liveTimeout)
            arm(id)
        }
    }

    func cancel(_ id: UUID, token: UUID) {
        resume(id, token: token, changed: false)
    }

    private func readerEnded(_ id: UUID) {
        guard readerId == id else { return }
        Log.perps.i("live feed: signals ended")
        reader = nil
        readerId = nil
        setLive(false)
    }

    private func handle(_ signal: PerpsRealtimeSignal, from id: UUID) {
        guard readerId == id else { return }
        switch signal {
        case let .subscribed(recovered):
            setLive(true)
            if !recovered {
                Log.perps.i("live feed: resync, waking \(listeners.count) listeners")
                listeners.keys.forEach(notify)
            }
        case .unsubscribed:
            setLive(false)
        case let .event(event):
            listeners.filter { $0.value.matches(event) }.keys.forEach(notify)
        }
    }

    private func setLive(_ live: Bool) {
        guard isLive != live else { return }
        isLive = live
        Log.perps.i("live feed: \(live ? "live, waits end on events" : "not live, waits run on timers")")
        listeners.keys.forEach(arm)
    }

    private func notify(_ id: UUID) {
        guard var listener = listeners[id] else { return }
        guard listener.debounce > 0 else {
            fire(id)
            return
        }
        guard listener.debounceTask == nil else { return }
        let delay = UInt64(listener.debounce * 1_000_000_000)
        listener.debounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: delay)
            guard !Task.isCancelled else { return }
            await self?.fire(id)
        }
        listeners[id] = listener
    }

    private func fire(_ id: UUID) {
        guard var listener = listeners[id] else { return }
        listener.debounceTask = nil
        if let token = listener.waiter?.token {
            listeners[id] = listener
            resume(id, token: token, changed: true)
        } else {
            listener.pending = true
            listeners[id] = listener
        }
    }

    private func arm(_ id: UUID) {
        guard var listener = listeners[id], var waiter = listener.waiter else { return }
        waiter.timer?.cancel()
        waiter.timer = (isLive ? waiter.liveTimeout : waiter.pollAfter).map { interval in
            let token = waiter.token
            return Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(max(interval, 0) * 1_000_000_000))
                guard !Task.isCancelled else { return }
                await self?.resume(id, token: token, changed: false)
            }
        }
        listener.waiter = waiter
        listeners[id] = listener
    }

    private func resume(_ id: UUID, token: UUID, changed: Bool) {
        guard var listener = listeners[id], let waiter = listener.waiter, waiter.token == token else { return }
        listener.waiter = nil
        listeners[id] = listener
        waiter.timer?.cancel()
        waiter.continuation.resume(returning: changed)
    }
}
