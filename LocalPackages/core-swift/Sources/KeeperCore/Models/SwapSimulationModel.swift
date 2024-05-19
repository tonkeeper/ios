import Foundation

public struct SwapSimulationModel {
  public let sendAmount: String
  public let recieveAmount: String
  public let swapRate: String
  public let details: SwapDetails
}

public struct SwapDetails {
  public let priceImpact: String
  public let minimumRecieved: String
  public let liquidityProviderFee: String
  public let blockchainFee: String
  public let route: SwapRoute
  public let providerName: String
}

public struct SwapRoute {
  public let tokenSymbolSend: String
  public let tokenSymbolRecieve: String
  
  public func toString() -> String {
    "\(tokenSymbolSend) » \(tokenSymbolRecieve)"
  }
}
