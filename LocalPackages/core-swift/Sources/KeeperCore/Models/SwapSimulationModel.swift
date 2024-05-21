import Foundation

public struct SwapSimulationModel: Equatable {
  public let sendAmount: String
  public let recieveAmount: String
  public let swapRate: Rate
  public let info: Info
  
  public init(sendAmount: String, recieveAmount: String, swapRate: Rate, info: Info) {
    self.sendAmount = sendAmount
    self.recieveAmount = recieveAmount
    self.swapRate = swapRate
    self.info = info
  }
}

extension SwapSimulationModel {
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
  public func outputAmount(for direction: SwapSimulationDirection) -> String {
    switch direction {
    case .direct:
      return recieveAmount
    case .reverse:
      return sendAmount
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
