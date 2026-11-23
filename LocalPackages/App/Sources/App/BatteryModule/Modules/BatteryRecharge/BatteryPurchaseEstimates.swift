import Foundation
import KeeperCore

@MainActor
final class BatteryPurchaseEstimates {
    enum State {
        case idle
        case loading
        case ready(BatteryPurchaseQuote)
        case failed(Error)
    }

    private let estimate: (BatteryPurchaseRequest) async throws -> BatteryPurchaseQuote
    private let debounce: () async throws -> Void
    private let didChange: (State) -> Void
    private var task: Task<Void, Never>?
    private var revision = 0

    init(estimate: @escaping (BatteryPurchaseRequest) async throws -> BatteryPurchaseQuote, debounce: @escaping () async throws -> Void, didChange: @escaping (State) -> Void) {
        self.estimate = estimate
        self.debounce = debounce
        self.didChange = didChange
    }

    @discardableResult
    func update(_ request: BatteryPurchaseRequest?) -> Task<Void, Never>? {
        cancel()
        guard let request else {
            didChange(.idle)
            return nil
        }
        let expected = revision
        didChange(.loading)
        let task = Task { [weak self, estimate, debounce] in
            do {
                try await debounce()
                try Task.checkCancellation()
                let quote = try await estimate(request)
                try Task.checkCancellation()
                guard let self, revision == expected else { return }
                didChange(.ready(quote))
            } catch {
                guard let self, !Task.isCancelled, revision == expected else { return }
                didChange(.failed(error))
            }
        }
        self.task = task
        return task
    }

    func cancel() {
        revision += 1
        task?.cancel()
        task = nil
    }
}
