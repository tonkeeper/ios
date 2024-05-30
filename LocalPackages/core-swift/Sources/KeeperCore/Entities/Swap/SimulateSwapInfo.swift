import Foundation

public struct SimulateSwapInfo: Codable {
    let askAddress: String
    let askUnits: String
    let feeAddress: String
    let feePercent: String
    let feeUnits: String
    let minAskUnits: String
    let offerAddress: String
    let offerUnits: String
    let poolAddress: String
    let priceImpact: String
    let routerAddress: String
    let slippageTolerance: String
    let swapRate: String
    
    enum CodingKeys: String, CodingKey {
        case askAddress = "ask_address"
        case askUnits = "ask_units"
        case feeAddress = "fee_address"
        case feePercent = "fee_percent"
        case feeUnits = "fee_units"
        case minAskUnits = "min_ask_units"
        case offerAddress = "offer_address"
        case offerUnits = "offer_units"
        case poolAddress = "pool_address"
        case priceImpact = "price_impact"
        case routerAddress = "router_address"
        case slippageTolerance = "slippage_tolerance"
        case swapRate = "swap_rate"
    }
}
