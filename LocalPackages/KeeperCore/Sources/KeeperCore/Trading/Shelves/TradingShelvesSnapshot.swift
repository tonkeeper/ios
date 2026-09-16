import Foundation
import TKTradingAPI

public struct TradingShelvesSnapshot: Equatable, Sendable {
    public var generatedAt: Date
    public var currency: Currency
    public var shelves: [TradingShelf]
}

extension TradingShelvesSnapshot {
    init(
        response: Components.Schemas.ShelvesConfigResponse,
        currency: Currency
    ) {
        self.init(
            generatedAt: response.generated_at,
            currency: currency,
            shelves: response.groups.compactMap(TradingShelf.init(shelf:))
        )
    }

    init(
        response: Components.Schemas.ShelvesConfigResponseV2,
        currency: Currency
    ) {
        self.init(
            generatedAt: response.generated_at,
            currency: currency,
            shelves: response.groups.compactMap(TradingShelf.init(multichainShelf:))
        )
    }
}
