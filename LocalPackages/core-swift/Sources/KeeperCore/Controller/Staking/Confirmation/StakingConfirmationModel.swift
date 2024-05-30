import Foundation

public struct StakingConfirmationModel {
  public let poolName: String
  public let poolImage: StakingPoolImage
  public let wallet: String
  public let apyPercent: String?
  public let operationName: String
  public let amount: String
  public let amountConverted: String?
  public let fee: LoadableModelItem<String>
  public let feeConverted: LoadableModelItem<String?>
  public let kind: StakingPool.Implementation.Kind
  public let tokenSymbol: String
}
