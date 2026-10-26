import PerpsModels

@MainActor
final class PerpsMarketPriceFeed {
    private let marketId: Int64
    private let store: any PerpsMarketsStoring
    private let interest: any PerpsPriceInteresting

    init(marketId: Int64, store: any PerpsMarketsStoring) {
        self.marketId = marketId
        self.store = store
        interest = store.makePriceInterest()
    }

    var livePrice: Double? {
        store.getState().livePrice(marketId: marketId).flatMap(Self.positive)
    }

    var price: Double? {
        store.getState().price(marketId: marketId).flatMap(Self.positive)
    }

    func subscribe() {
        interest.set(marketIds: [marketId])
    }

    func unsubscribe() {
        interest.clear()
    }

    func observe<Observer: AnyObject>(_ observer: Observer, onChange: @escaping @MainActor (Observer) -> Void) {
        store.addChangeObserver(observer) { observer in
            Task { @MainActor in onChange(observer) }
        }
    }

    private static func positive(_ price: Double) -> Double? {
        price > 0 ? price : nil
    }
}
