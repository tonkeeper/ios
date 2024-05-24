import Foundation

public struct SwapEstimateResponse: Codable {
  public var result: SwapEstimate
}

public struct SwapEstimate: Codable {
  public var offerAddress: String?
  public var askAddress: String?
  public var routerAddress: String?
  public var poolAddress: String?
  public var offerUnits: Int64?
  public var askUnits: Int64?
  public var slippageTolerance: String?
  public var minAskUnits: Int64?
  public var swapRate: String?
  public var priceImpact: Double?
  public var feeAddress: String?
  public var feeUnits: Int64?
  public var feePercent: String?

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
  
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.offerAddress = try? container.decodeIfPresent(String.self, forKey: .offerAddress)
    self.askAddress = try? container.decodeIfPresent(String.self, forKey: .askAddress)
    self.routerAddress = try? container.decodeIfPresent(String.self, forKey: .routerAddress)
    self.poolAddress = try? container.decodeIfPresent(String.self, forKey: .poolAddress)
    if let offerUnits = try? container.decodeIfPresent(String.self, forKey: .offerUnits) {
      self.offerUnits = Int64(offerUnits)
    }
    if let askUnits = try? container.decodeIfPresent(String.self, forKey: .askUnits) {
      self.askUnits = Int64(askUnits)
    }
    self.slippageTolerance = try? container.decodeIfPresent(String.self, forKey: .slippageTolerance)
    if let minAskUnits = try? container.decodeIfPresent(String.self, forKey: .minAskUnits) {
      self.minAskUnits = Int64(minAskUnits)
    }
    self.swapRate = try? container.decodeIfPresent(String.self, forKey: .swapRate)
    if let priceImpact = try? container.decodeIfPresent(String.self, forKey: .priceImpact) {
      self.priceImpact = Double(priceImpact)
    }
    self.feeAddress = try? container.decodeIfPresent(String.self, forKey: .feeAddress)
    if let feeUnits = try? container.decodeIfPresent(String.self, forKey: .feeUnits) {
      self.feeUnits = Int64(feeUnits)
    }
    self.feePercent = try? container.decodeIfPresent(String.self, forKey: .feePercent)
  }
}
