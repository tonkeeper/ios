import Foundation

public final class TonRatesStore: Store<TonRatesStore.Event, TonRatesStore.State> {
    public struct State {
        public let tonRates: [Rates.Rate]
        public let usdtRates: [Rates.Rate]
        public let jettonRates: [String: [Rates.Rate]]
    }

    public enum Event {
        case didUpdateRates(state: State)
    }

    private let repository: RatesRepository

    init(repository: RatesRepository) {
        self.repository = repository
        super.init(state: State(tonRates: [], usdtRates: [], jettonRates: [:]))
    }

    override public func createInitialState() -> State {
        do {
            let rates = try repository.getRates()
            return State(tonRates: rates.ton, usdtRates: rates.usdt, jettonRates: rates.jettonRates)
        } catch {
            return State(tonRates: [], usdtRates: [], jettonRates: [:])
        }
    }

    public func setRates(
        ton: [Rates.Rate],
        usdt: [Rates.Rate],
        jettonRates: [String: [Rates.Rate]]
    ) async {
        return await withCheckedContinuation { continuation in
            setRates(ton: ton, usdt: usdt, jettonRates: jettonRates) {
                continuation.resume()
            }
        }
    }

    public func setRates(
        ton: [Rates.Rate],
        usdt: [Rates.Rate],
        jettonRates: [String: [Rates.Rate]],
        completion: @escaping () -> Void
    ) {
        updateState { [repository] _ in
            try? repository.saveRates(Rates(ton: ton, usdt: usdt, jettonRates: jettonRates))
            return StateUpdate(newState: State(tonRates: ton, usdtRates: usdt, jettonRates: jettonRates))
        } completion: { [weak self] state in
            guard let self else { return }
            self.sendEvent(.didUpdateRates(state: state))
            completion()
        }
    }
}
