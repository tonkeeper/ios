import Foundation
import TonSwift
import BigInt

struct StonfiSwapSimulation {
  let offerAddress: Address
  let askAddress: Address
  let routerAddress: Address
  let poolAddress: Address
  let offerUnits: BigUInt
  let askUnits: BigUInt
  let slippageTolerance: String
  let minAskUnits: BigUInt
  let swapRate: Decimal
  let priceImpact: Decimal
  let feeAddress: Address
  let feeUnits: BigUInt
  let feePercent: String
}

struct StonfiSwapSimulationResult: Codable {
  let offerAddress: String
  let askAddress: String
  let routerAddress: String
  let poolAddress: String
  let offerUnits: String
  let askUnits: String
  let slippageTolerance: String
  let minAskUnits: String
  let swapRate: String
  let priceImpact: String
  let feeAddress: String
  let feeUnits: String
  let feePercent: String
  
  enum CodingKeys: String, CodingKey {
    case offerAddress = "offer_address"
    case askAddress = "ask_address"
    case routerAddress = "router_address"
    case poolAddress = "pool_address"
    case offerUnits = "offer_units"
    case askUnits = "ask_units"
    case slippageTolerance = "slippage_tolerance"
    case minAskUnits = "min_ask_units"
    case swapRate = "swap_rate"
    case priceImpact = "price_impact"
    case feeAddress = "fee_address"
    case feeUnits = "fee_units"
    case feePercent = "fee_percent"
  }
}

extension StonfiSwapSimulationResult {
  init() {
    self.offerAddress = ""
    self.askAddress = ""
    self.routerAddress = ""
    self.poolAddress = ""
    self.offerUnits = ""
    self.askUnits = ""
    self.slippageTolerance = ""
    self.minAskUnits = ""
    self.swapRate = ""
    self.priceImpact = ""
    self.feeAddress = ""
    self.feeUnits = ""
    self.feePercent = ""
  }
}
