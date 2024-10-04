import Foundation

public struct StakeConfirmationModel {
  public let poolName: String
  public let poolImplementation: StackingPoolInfo.Implementation
  public let wallet: Wallet
  public let apyPercent: String?
  public let operationName: String
  public let amount: String
  public let amountConverted: String?
  public let fee: LoadableModelItem<String>
  public let feeConverted: LoadableModelItem<String?>
  public let tokenSymbol: String
  public let buttonTitle: String
}
