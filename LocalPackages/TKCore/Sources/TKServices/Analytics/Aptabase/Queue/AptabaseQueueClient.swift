import Foundation

struct AptabasePendingEvent: Sendable {
    let name: String
    let props: [String: AptabasePropValue]
    /// Captured synchronously at the `logEvent` call so queueing latency never skews the timestamp.
    let timestamp: Date
}

/// Everything the client reacts to arrives through one ordered channel, so a lifecycle transition can
/// never overtake the events logged before it.
enum AptabaseQueueInput: Sendable {
    case event(AptabasePendingEvent)
    /// The app became active again: the periodic flush restarts.
    case resumed
    /// A usable network appeared. Whatever backoff the offline stretch built up is dropped, so the
    /// queue does not sit on a five-minute pause with connectivity already back.
    case networkAvailable
    /// The app is going to the background. `completion` releases whatever is keeping the process alive
    /// for the final flush, and is called once that flush is over.
    case suspended(completion: @MainActor @Sendable () -> Void)
}

/// Single isolation domain for everything that has to change coherently: the session, the durable
/// store, the flush cycle and the retry state.
///
/// Input arrives as an `AsyncStream` fed by `AptabaseQueuedService`, which owns the synchronous side of
/// the boundary. One consumer drains it in order; a `Task` per event would leave that order undefined.
actor AptabaseQueueClient {
    /// Same as the SDK: a session ends after an hour of inactivity.
    static let sessionTimeout: TimeInterval = 60 * 60
    private static let maximumBatchesPerFlush = 64
    private static let maximumBackoff: TimeInterval = 5 * 60
    private static let flushThreshold = 50

    private let store: AptabaseEventStore
    private let dispatcher: AptabaseDispatcher
    private let environment: AptabaseEnvironment
    private let flushInterval: TimeInterval
    private let currentDate: @Sendable () -> Date

    private var sessionId: String
    private var lastTouched: Date
    private var consumerTask: Task<Void, Never>?
    private var tickerTask: Task<Void, Never>?
    private var flushTask: Task<Void, Never>?
    private var backoffInterval: TimeInterval = 0
    private var backoffUntil: Date?
    private var isStarted = false

    init(
        store: AptabaseEventStore,
        dispatcher: AptabaseDispatcher,
        environment: AptabaseEnvironment,
        flushInterval: TimeInterval,
        currentDate: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.store = store
        self.dispatcher = dispatcher
        self.environment = environment
        self.flushInterval = flushInterval
        self.currentDate = currentDate

        let now = currentDate()
        sessionId = Self.makeSessionId(at: now)
        lastTouched = now
    }

    /// Single-flight: the ticker, the 50-event threshold and backgrounding can all ask for a flush at
    /// once, and two concurrent cycles would `peek` the same batch and send it twice. `flushTask` is what
    /// a second caller can await, so it cannot collapse into a direct `performFlush()` call.
    func flush() async {
        if let flushTask {
            await flushTask.value
            return
        }
        if let backoffUntil, currentDate() < backoffUntil {
            return
        }
        let task = Task { await self.performFlush() }
        flushTask = task
        await task.value
        flushTask = nil
    }

    func pendingCount() async -> Int {
        await store.count
    }

    /// Idempotent.
    func start(consuming inputs: AsyncStream<AptabaseQueueInput>) async {
        guard !isStarted else { return }
        isStarted = true
        startConsumer(inputs)
        startTicker()
        // Whatever the previous session left on disk goes out first.
        await flush()
    }
}

private extension AptabaseQueueClient {
    func startConsumer(_ inputs: AsyncStream<AptabaseQueueInput>) {
        consumerTask = Task {
            defer { self.stopTicker() }
            var sinceFlush = 0
            for await input in inputs {
                switch input {
                case let .event(pending):
                    await self.enqueue(pending)
                    sinceFlush += 1
                    if sinceFlush >= Self.flushThreshold {
                        sinceFlush = 0
                        // Detached from the loop so the consumer keeps persisting while a flush uploads.
                        Task { await self.flush() }
                    }
                case .resumed:
                    self.startTicker()
                case .networkAvailable:
                    self.resetBackoff()
                    // Detached so the consumer keeps draining while the flush uploads.
                    Task { await self.flush() }
                case let .suspended(completion):
                    sinceFlush = 0
                    self.stopTicker()
                    // Reached only after every event logged before the transition is on disk.
                    await self.flush()
                    await MainActor.run { completion() }
                }
            }
        }
    }

    func enqueue(_ pending: AptabasePendingEvent) async {
        let event = AptabaseEvent(
            timestamp: pending.timestamp,
            sessionId: sessionId(at: pending.timestamp),
            eventName: pending.name,
            systemProps: environment.systemProps,
            props: pending.props
        )
        await store.append(event)
    }

    func startTicker() {
        tickerTask?.cancel()
        tickerTask = Task { [flushInterval] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(flushInterval * 1_000_000_000))
                guard !Task.isCancelled else { return }
                await self.flush()
            }
        }
    }

    func stopTicker() {
        tickerTask?.cancel()
        tickerTask = nil
    }

    func performFlush() async {
        for _ in 0 ..< Self.maximumBatchesPerFlush {
            let batch = await store.peek(limit: AptabaseDispatcher.maximumBatchSize)
            guard !batch.events.isEmpty else { return }

            switch await dispatcher.send(batch.events) {
            case .delivered:
                await store.remove(upTo: batch.upperBound)
                resetBackoff()
            case .rejected:
                // `/api/v0/events` filters the events it cannot accept and still answers 200, so a 4xx
                // condemns the request as a whole — one event failing model validation, or an
                // account-level error. Resending the batch one event at a time keeps everything the
                // server still accepts and loses only what it actually refuses.
                if batch.events.count > 1 {
                    guard await sendIndividually(batch) else { return }
                }
                await store.remove(upTo: batch.upperBound)
                resetBackoff()
            case .retry:
                scheduleBackoff()
                return
            }
        }
    }

    /// `false` means the connection dropped part-way through: the events already accounted for are off
    /// the queue and the rest stays for the next flush. An event the server refuses on its own is
    /// dropped — it is the one the batch was rejected for.
    func sendIndividually(_ batch: AptabaseEventStore.Batch) async -> Bool {
        let lowerBound = batch.upperBound - batch.events.count
        for (index, event) in batch.events.enumerated() {
            guard case .retry = await dispatcher.send([event]) else { continue }
            await store.remove(upTo: lowerBound + index)
            scheduleBackoff()
            return false
        }
        return true
    }

    func resetBackoff() {
        backoffInterval = 0
        backoffUntil = nil
    }

    func scheduleBackoff() {
        backoffInterval = backoffInterval == 0
            ? 1
            : min(backoffInterval * 2, Self.maximumBackoff)
        backoffUntil = currentDate().addingTimeInterval(backoffInterval * Double.random(in: 0.8 ... 1.2))
    }

    func sessionId(at timestamp: Date) -> String {
        if lastTouched.distance(to: timestamp) > Self.sessionTimeout {
            sessionId = Self.makeSessionId(at: timestamp)
        }
        lastTouched = timestamp
        return sessionId
    }

    static func makeSessionId(at date: Date) -> String {
        let epochInSeconds = UInt64(max(0, date.timeIntervalSince1970))
        let random = UInt64.random(in: 0 ... 99_999_999)
        return String(epochInSeconds * 100_000_000 + random)
    }
}
