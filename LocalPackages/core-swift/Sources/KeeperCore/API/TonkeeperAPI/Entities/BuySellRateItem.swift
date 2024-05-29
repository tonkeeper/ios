import Foundation

public struct BuySellRateItem: Codable {
    public let id: String
    public let name: String
    public let rate: Double
    public let currency: String
    public let logo: URL
    public let minTonBuyAmount: Int64?
    public let minTonSellAmount: Int64?
    
    enum CodingKeys: String, CodingKey {
        case id, name, rate, currency, logo
        case minTonBuyAmount = "min_ton_buy_amount"
        case minTonSellAmount = "min_ton_sell_amount"
    }
}

public struct BuySellRateItemsResponse: Codable {
    public let items: [BuySellRateItem]
}
