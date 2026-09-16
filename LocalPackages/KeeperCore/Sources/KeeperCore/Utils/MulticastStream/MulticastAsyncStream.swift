import Foundation

private enum Command<Element: Sendable> {
    case add(
        id: UUID,
        continuation: AsyncStream<Element>.Continuation,
        registered: CheckedContinuation<Void, Never>
    )
    case remove(id: UUID)
    case emit(Element)
}

final class MulticastAsyncStream<Element: Sendable>: Sendable {
    private let commandContinuation: AsyncStream<Command<Element>>.Continuation
    private let workerTask: Task<Void, Never>

    init() {
        let (commandStream, commandContinuation) = AsyncStream<Command<Element>>.makeStream()
        self.commandContinuation = commandContinuation
        self.workerTask = spawnWorkingTask(stream: commandStream)
    }

    deinit {
        commandContinuation.finish()
        workerTask.cancel()
    }

    nonisolated func unicast() async -> AsyncStream<Element> {
        let id = UUID()
        let (stream, continuation) = AsyncStream<Element>.makeStream()
        continuation.onTermination = { [commandContinuation] _ in
            commandContinuation.yield(.remove(id: id))
        }
        await withCheckedContinuation { registered in
            commandContinuation.yield(
                .add(
                    id: id,
                    continuation: continuation,
                    registered: registered
                )
            )
        }
        return stream
    }

    nonisolated func emit(_ event: Element) {
        commandContinuation.yield(.emit(event))
    }
}

// MARK: -

private func spawnWorkingTask<Element: Sendable>(
    stream: AsyncStream<Command<Element>>
) -> Task<Void, Never> {
    Task {
        var continuations = [UUID: AsyncStream<Element>.Continuation]()
        for await command in stream {
            switch command {
            case let .add(id, continuation, registered):
                continuations[id] = continuation
                registered.resume()

            case let .remove(id):
                continuations.removeValue(forKey: id)

            case let .emit(event):
                for continuation in continuations.values {
                    continuation.yield(event)
                }
            }
        }
        for continuation in continuations.values {
            continuation.finish()
        }
    }
}
