import Foundation
import TKLogging

public final class PerpsMarketDetailsStore: Store<PerpsMarketDetailsStore.Event, PerpsMarketDetailsStore.State>, @unchecked Sendable {
    public enum State: Equatable {
        case idle
        case loading
        case loaded(PerpsAssetMarketSnapshot)
        case failed
        case notFound
    }

    public enum Event {
        case didUpdate(State)
    }

    private let service: PerpsMarketDetailsLoading

    private let lifecycleLock = NSLock()
    private var loadTask: Task<Void, Never>?
    private var loadedMarketId: Int64?

    init(service: PerpsMarketDetailsLoading) {
        self.service = service
        super.init(state: .idle)
    }

    deinit {
        loadTask?.cancel()
    }

    override public func createInitialState() -> State {
        .idle
    }

    public func load(marketId: Int64) {
        reload(marketId: marketId, showLoading: true)
    }
}

private extension PerpsMarketDetailsStore {
    func reload(marketId: Int64, showLoading: Bool) {
        if showLoading {
            apply(.loading, for: marketId)
        }
        let previousTask = lifecycleLock.withLock { () -> Task<Void, Never>? in
            let previousTask = loadTask
            loadedMarketId = marketId
            loadTask = Task { [weak self] in
                guard let self else { return }
                let outcome: State
                do {
                    outcome = try .loaded(await service.load(marketId: marketId))
                } catch PerpsMarketDetailsLoadError.notFound {
                    outcome = .notFound
                } catch {
                    Log.w("🪵 Perps: market details load failed — \(error)")
                    outcome = .failed
                }
                guard !Task.isCancelled else { return }
                self.apply(outcome, for: marketId)
            }
            return previousTask
        }
        previousTask?.cancel()
    }

    func apply(_ outcome: State, for marketId: Int64) {
        updateState { [weak self] state in
            guard let self, self.lifecycleLock.withLock({ self.loadedMarketId == marketId }) else { return nil }
            switch outcome {
            case .loaded:
                return StateUpdate(newState: outcome)
            case .loading:
                if case let .loaded(snapshot) = state, snapshot.marketId == marketId { return nil }
                return StateUpdate(newState: outcome)
            case .failed, .notFound:
                if case .loaded = state { return nil }
                return StateUpdate(newState: outcome)
            case .idle:
                return nil
            }
        } completion: { [weak self] state in
            guard state == outcome else { return }
            self?.sendEvent(.didUpdate(state))
        }
    }
}
