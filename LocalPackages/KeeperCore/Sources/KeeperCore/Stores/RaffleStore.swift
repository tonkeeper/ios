import Foundation

/// Holds the raffles last fetched from the wallet-scoped backend endpoint.
/// `RaffleLoader` feeds it; UI observes `didUpdateRaffles`.
public final class RaffleStore: Store<RaffleStore.Event, RaffleStore.State> {
    public typealias State = [MultichainRaffle]

    public enum Event {
        case didUpdateRaffles(raffles: [MultichainRaffle])
    }

    init() {
        super.init(state: [])
    }

    override public func createInitialState() -> State {
        []
    }

    public func setRaffles(_ raffles: [MultichainRaffle]) async {
        await withCheckedContinuation { continuation in
            setRaffles(raffles) {
                continuation.resume()
            }
        }
    }

    private func setRaffles(_ raffles: [MultichainRaffle], completion: (() -> Void)? = nil) {
        updateState { _ in
            StateUpdate(newState: raffles)
        } completion: { [weak self] _ in
            self?.sendEvent(.didUpdateRaffles(raffles: raffles))
            completion?()
        }
    }
}
