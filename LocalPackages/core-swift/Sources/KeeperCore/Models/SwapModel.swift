import UIKit
import BigInt
import TonSwift

public struct SwapModel {
  public let confirmationItem: SwapConfirmationItem
  public let transactionItem: SwapTransactionItem
  
  public init(confirmationItem: SwapConfirmationItem, transactionItem: SwapTransactionItem) {
    self.confirmationItem = confirmationItem
    self.transactionItem = transactionItem
  }
}

public struct SwapConfirmationItem {
  public let convertedFiatAmount: String
  public let operationItem: SwapOperationItem
  public let simulationModel: SwapSimulationModel
  
  public init(convertedFiatAmount: String, operationItem: SwapOperationItem, simulationModel: SwapSimulationModel) {
    self.convertedFiatAmount = convertedFiatAmount
    self.operationItem = operationItem
    self.simulationModel = simulationModel
  }
}

public struct SwapOperationItem {
  public var sendToken: SwapToken?
  public var recieveToken: SwapToken?
  
  public init(sendToken: SwapToken? = nil, recieveToken: SwapToken? = nil) {
    self.sendToken = sendToken
    self.recieveToken = recieveToken
  }
}

public struct SwapToken {
  public enum Icon {
    case image(UIImage)
    case asyncImage(URL?)
  }
  
  public var icon: Icon
  public var asset: SwapAsset
  public var balance: BigUInt
  public var inputAmount: String
  
  public init(icon: Icon, asset: SwapAsset, balance: BigUInt, inputAmount: String) {
    self.icon = icon
    self.asset = asset
    self.balance = balance
    self.inputAmount = inputAmount
  }
}

public enum SwapTransactionItem {
  case jettonToJetton(SwapItem)
  case jettonToTon(SwapItem)
  case tonToJetton(SwapItem)
}

public struct SwapItem {
  public let fromAddress: Address
  public let toAddress: Address
  public let minAskAmount: BigUInt
  public let offerAmount: BigUInt
  
  public init(fromAddress: Address, toAddress: Address, minAskAmount: BigUInt, offerAmount: BigUInt) {
    self.fromAddress = fromAddress
    self.toAddress = toAddress
    self.minAskAmount = minAskAmount
    self.offerAmount = offerAmount
  }
}
