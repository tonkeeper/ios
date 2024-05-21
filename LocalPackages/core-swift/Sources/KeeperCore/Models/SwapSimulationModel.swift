import Foundation

public struct SwapSimulationModel: Equatable {
  public struct Info: Equatable {
    public struct Route: Equatable {
      public let tokenSymbolSend: String
      public let tokenSymbolRecieve: String
    }
    
    public let priceImpact: String
    public let minimumRecieved: String
    public let liquidityProviderFee: String
    public let blockchainFee: String
    public let route: Route
    public let providerName: String
  }
  
  public struct Rate: Equatable {
    public let value: String
  }
  
  public let sendAmount: String
  public let recieveAmount: String
  public let swapRate: Rate
  public let info: Info
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
