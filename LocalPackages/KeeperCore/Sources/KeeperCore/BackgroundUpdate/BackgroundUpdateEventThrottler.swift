import Foundation

/// Collapses a burst of streaming updates into a leading and a coalesced trailing event.
actor BackgroundUpdateEventThrottler {
    private struct TrailingEmission {
        var event: BackgroundUpdateEvent
        let task: Task<Void, Never>
    }

    let events: AsyncStream<BackgroundUpdateEvent>

    private let inputContinuation: AsyncStream<BackgroundUpdateEvent>.Continuation
    private let eventContinuation: AsyncStream<BackgroundUpdateEvent>.Continuation

    private let interval: TimeInterval
    private let now: @Sendable () -> Date
    private let sleep: Sleep

    private var lastEmissionDate: Date?
    private var trailingEmission: TrailingEmission?

    typealias Sleep = @Sendable (_ delay: TimeInterval) async throws -> Void

    init(
        interval: TimeInterval,
        now: @escaping @Sendable () -> Date = { Date() },
        sleep: @escaping Sleep = BackgroundUpdateEventThrottler.defaultSleep
    ) {
        let (inputEvents, inputContinuation) = AsyncStream<BackgroundUpdateEvent>.makeStream()
        self.inputContinuation = inputContinuation
        (events, eventContinuation) = AsyncStream<BackgroundUpdateEvent>.makeStream()
        self.interval = interval
        self.now = now
        self.sleep = sleep

        Task { [weak self, inputEvents] in
            for await event in inputEvents {
                guard let self else { return }
                await process(event)
            }
            await self?.finishProcessing()
        }
    }

    deinit {
        inputContinuation.finish()
        eventContinuation.finish()
    }

    nonisolated func receive(_ event: BackgroundUpdateEvent) {
        inputContinuation.yield(event)
    }

    /// Terminal, callable from a synchronous session shutdown: it only closes the input, and the
    /// consumer drains into `finishProcessing()` inside the actor.
    nonisolated func finish() {
        inputContinuation.finish()
    }

    private func finishProcessing() {
        trailingEmission?.task.cancel()
        trailingEmission = nil
        eventContinuation.finish()
    }

    private func process(_ event: BackgroundUpdateEvent) {
        let date = now()
        let elapsed = lastEmissionDate.map { date.timeIntervalSince($0) }

        guard let elapsed, elapsed < interval else {
            trailingEmission?.task.cancel()
            trailingEmission = nil
            lastEmissionDate = date
            eventContinuation.yield(event)
            return
        }

        if var trailingEmission {
            trailingEmission.event = event
            self.trailingEmission = trailingEmission
            return
        }

        let delay = interval - elapsed
        let sleep = sleep
        let task = Task { [weak self] in
            do {
                try await sleep(delay)
                try Task.checkCancellation()
                await self?.emitPendingEvent()
            } catch {
                return
            }
        }
        trailingEmission = TrailingEmission(event: event, task: task)
    }

    private func emitPendingEvent() {
        guard !Task.isCancelled else { return }
        guard let trailingEmission else { return }

        self.trailingEmission = nil
        lastEmissionDate = now()
        eventContinuation.yield(trailingEmission.event)
    }
}

private extension BackgroundUpdateEventThrottler {
    static let defaultSleep: Sleep = { delay in
        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
    }
}
