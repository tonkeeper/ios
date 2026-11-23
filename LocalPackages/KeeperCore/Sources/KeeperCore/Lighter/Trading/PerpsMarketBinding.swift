import Foundation
import PerpsModels
import TKPerpsAPI

enum PerpsMarketBinding {
    static let refusalReason = "market_binding"

    static func requireRequestedMarket(_ marketId: Int64, screen: Components.Schemas.TradingScreen) throws {
        if let position = screen.position?.value1 {
            try requireMarket(marketId, subject: "the position", served: position.market_index)
        }
        for order in screen.open_orders ?? [] {
            try requireMarket(marketId, subject: "order \(order.order_index.map(String.init) ?? "?")", served: order.market_index)
        }
    }

    static func requireRequestedMarket(_ marketId: Int64, detail: Components.Schemas.OpenPositionDetail) throws {
        try requireMarket(marketId, subject: "the position detail", served: detail.position?.market_index)
    }

    private static func requireMarket(_ marketId: Int64, subject: String, served: Int?) throws {
        guard served.map(Int64.init) == marketId else {
            throw PerpsSignedMarketRefusal(
                error: .validation("\(subject) is served for market \(served.map(String.init) ?? "nil"), not the requested \(marketId)"),
                reason: refusalReason
            )
        }
    }
}
