import Foundation
import PerpsModels

final class PerpsPositionsController: Sendable {
    typealias MakeWatch = @Sendable (
        PerpsPositionsCadence,
        @escaping @Sendable (PerpsAccountTick) -> Void,
        @escaping @Sendable () -> Void
    ) -> PerpsPositionsWatch

    private enum Command: Sendable {
        case subscribe(PerpsPositionsCadence)
        case unsubscribe(PerpsPositionsCadence)
        case start
        case stop(CheckedContinuation<Void, Never>)
        case stopIfIdle
        case flush(CheckedContinuation<Void, Never>)
        case flushed
    }

    private enum WatchEvent: Sendable {
        case update(PerpsAccountTick)
        case interrupted
        case flush(acknowledged: Bool)
    }

    private struct Watch: Sendable {
        let cadence: PerpsPositionsCadence
        let handle: PerpsPositionsWatch
        let events: AsyncStream<WatchEvent>.Continuation
        let consumer: Task<Void, Never>
        let timer: Task<Void, Never>

        func cancel() async {
            consumer.cancel()
            events.finish()
            handle.cancel()
            timer.cancel()
            // Cancellation is cooperative; a replacement must wait for the last apply to finish.
            await consumer.value
            await timer.value
        }
    }

    private let commands: AsyncStream<Command>.Continuation

    init(
        makeWatch: @escaping MakeWatch,
        onUpdate: @escaping @Sendable (PerpsAccountTick) -> Void,
        onInterrupted: @escaping @Sendable () -> Void,
        onStop: @escaping @Sendable () -> Void
    ) {
        let (stream, commands) = AsyncStream<Command>.makeStream()
        self.commands = commands
        Task {
            var subscribers = [PerpsPositionsCadence: Int]()
            var watch: Watch?
            var idleStop: Task<Void, Never>?
            var isActive = false
            // Waiters live here rather than in the watch's event stream: cancelling a watch drops
            // whatever it had buffered, and a flush that vanished with it would never resume.
            var flushWaiters = [CheckedContinuation<Void, Never>]()

            func resumeFlushWaiters() {
                let waiting = flushWaiters
                flushWaiters = []
                for waiter in waiting {
                    waiter.resume()
                }
            }

            func dropWatch() async {
                idleStop?.cancel()
                idleStop = nil
                await watch?.cancel()
                watch = nil
                resumeFlushWaiters()
                onStop()
            }

            for await command in stream {
                switch command {
                case let .subscribe(cadence):
                    subscribers[cadence, default: 0] += 1
                    idleStop?.cancel()
                    idleStop = nil
                case let .unsubscribe(cadence):
                    let count = max(0, (subscribers[cadence] ?? 0) - 1)
                    subscribers[cadence] = count > 0 ? count : nil
                    if subscribers.isEmpty {
                        idleStop?.cancel()
                        idleStop = Task {
                            try? await Task.sleep(nanoseconds: 2_000_000_000)
                            guard !Task.isCancelled else { return }
                            commands.yield(.stopIfIdle)
                        }
                    }
                case .start:
                    isActive = true
                case let .stop(completion):
                    isActive = false
                    await dropWatch()
                    completion.resume()
                case .stopIfIdle:
                    guard subscribers.isEmpty else { continue }
                    await dropWatch()
                case let .flush(completion):
                    guard let watch else {
                        completion.resume()
                        continue
                    }
                    flushWaiters.append(completion)
                    watch.events.yield(.flush(acknowledged: true))
                case .flushed:
                    resumeFlushWaiters()
                }
                guard isActive,
                      let cadence = PerpsPositionsCadence.allCases.first(where: { subscribers[$0] != nil }),
                      watch?.cadence != cadence
                else { continue }
                await watch?.cancel()
                resumeFlushWaiters()
                onStop()
                watch = Self.makeWatch(
                    cadence: cadence,
                    commands: commands,
                    makeWatch: makeWatch,
                    onUpdate: onUpdate,
                    onInterrupted: onInterrupted
                )
            }
            await dropWatch()
        }
    }

    deinit {
        commands.finish()
    }

    func subscribe(cadence: PerpsPositionsCadence) {
        commands.yield(.subscribe(cadence))
    }

    func unsubscribe(cadence: PerpsPositionsCadence) {
        commands.yield(.unsubscribe(cadence))
    }

    func start() {
        commands.yield(.start)
    }

    func stop() async {
        await withCheckedContinuation { commands.yield(.stop($0)) }
    }

    /// Returns once the pending tick has been applied, so a caller can read the result
    /// straight afterwards instead of waiting for it to appear.
    func flush() async {
        await withCheckedContinuation { commands.yield(.flush($0)) }
    }

    private static func makeWatch(
        cadence: PerpsPositionsCadence,
        commands: AsyncStream<Command>.Continuation,
        makeWatch: MakeWatch,
        onUpdate: @escaping @Sendable (PerpsAccountTick) -> Void,
        onInterrupted: @escaping @Sendable () -> Void
    ) -> Watch {
        let (stream, events) = AsyncStream<WatchEvent>.makeStream()
        let consumer = Task {
            var pending: PerpsAccountTick?
            for await event in stream {
                guard !Task.isCancelled else { return }
                switch event {
                case let .update(tick):
                    pending = tick
                case .interrupted:
                    onInterrupted()
                case let .flush(acknowledged):
                    if let tick = pending {
                        pending = nil
                        onUpdate(tick)
                    }
                    if acknowledged { commands.yield(.flushed) }
                }
            }
        }
        let handle = makeWatch(cadence, { events.yield(.update($0)) }, { events.yield(.interrupted) })
        let timer = Task {
            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: 500_000_000)
                } catch {
                    return
                }
                events.yield(.flush(acknowledged: false))
            }
        }
        return Watch(cadence: cadence, handle: handle, events: events, consumer: consumer, timer: timer)
    }
}
