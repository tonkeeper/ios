import Foundation

@MainActor
final class KeyboardDeleteRepeat {
    private let sleep: @MainActor (UInt64) async throws -> Void
    private var task: Task<Void, Never>?

    init(sleep: @escaping @MainActor (UInt64) async throws -> Void = { try await Task.sleep(nanoseconds: $0) }) {
        self.sleep = sleep
    }

    func start(onRepeat: @escaping @MainActor () -> Void, onClear: @escaping @MainActor () -> Void) {
        task?.cancel()
        let sleep = sleep
        task = Task {
            for tick in 1 ... Self.clearTick {
                try? await sleep(Self.tickNanoseconds)
                guard !Task.isCancelled else { return }
                guard tick >= Self.firstRepeatTick else { continue }
                if tick == Self.clearTick {
                    onClear()
                } else {
                    onRepeat()
                }
            }
        }
    }

    func cancel() {
        task?.cancel()
    }

    private static let tickNanoseconds: UInt64 = 100_000_000
    private static let firstRepeatTick = 5
    private static let clearTick = 10
}
