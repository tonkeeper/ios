import Foundation
import BigInt

public struct SwapItem {
  
  public var token: SwapToken
  public var amount: BigUInt
  
  public init(token: SwapToken, amount: BigUInt) {
    self.token = token
    self.amount = amount
  }
  
  public var contractAddress: String? {
    switch token {
    case .ton:
      return "EQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAM9c"
    case .jetton(let asset):
      return asset.contractAddress ?? ""
    }
  }
  
  public var symbol: String {
    switch token {
    case .ton:
      return "TON"
    case .jetton(let asset):
      return asset.symbol
    }
  }
  
  public var decimals: Int {
    switch token {
    case .ton:
      return 9
    case .jetton(let asset):
      return asset.decimals
    }
  }
}
