import Foundation
import BigInt

public struct SwapSimulationModel: Equatable {
  public let offerAmount: Amount
  public let askAmount: Amount
  public let minAskAmount: Amount
  public let swapRate: Rate
  public let info: Info
  
  public init(offerAmount: Amount, askAmount: Amount, minAskAmount: Amount, swapRate: Rate, info: Info) {
    self.offerAmount = offerAmount
    self.askAmount = askAmount
    self.minAskAmount = minAskAmount
    self.swapRate = swapRate
    self.info = info
  }
}

extension SwapSimulationModel {
  public struct Amount: Equatable {
    public let amount: BigUInt
    public let converted: String
    
    public init(amount: BigUInt, converted: String) {
      self.amount = amount
      self.converted = converted
    }
  }
  
  public struct Rate: Equatable {
    public let value: String
    
    public init(value: String) {
      self.value = value
    }
  }
  
  public struct Info: Equatable {
    public let priceImpact: String
    public let minimumRecieved: String
    public let liquidityProviderFee: String
    public let blockchainFee: String
    public let route: Route
    public let providerName: String
    
    public init(priceImpact: String, minimumRecieved: String, liquidityProviderFee: String, blockchainFee: String, route: Route, providerName: String) {
      self.priceImpact = priceImpact
      self.minimumRecieved = minimumRecieved
      self.liquidityProviderFee = liquidityProviderFee
      self.blockchainFee = blockchainFee
      self.route = route
      self.providerName = providerName
    }
  }
}

extension SwapSimulationModel.Info {
  public struct Route: Equatable {
    public let tokenSymbolSend: String
    public let tokenSymbolRecieve: String
    
    public init(tokenSymbolSend: String, tokenSymbolRecieve: String) {
      self.tokenSymbolSend = tokenSymbolSend
      self.tokenSymbolRecieve = tokenSymbolRecieve
    }
  }
}

public enum SwapSimulationDirection {
  case direct
  case reverse
}

extension SwapSimulationModel {
  public func outputAmount(for direction: SwapSimulationDirection) -> Amount {
    switch direction {
    case .direct:
      return askAmount
    case .reverse:
      return offerAmount
    }
  }
}

extension SwapSimulationModel.Rate {
  public func toString(route: SwapSimulationModel.Info.Route) -> String {
    "1 \(route.tokenSymbolSend) ≈ \(value) \(route.tokenSymbolRecieve)"
  }
}

extension SwapSimulationModel.Info.Route {
  public func toString() -> String {
    "\(tokenSymbolSend) » \(tokenSymbolRecieve)"
  }
}
