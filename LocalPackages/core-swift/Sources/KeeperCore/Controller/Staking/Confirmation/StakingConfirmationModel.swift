import Foundation

public struct StakingConfirmationModel {
  public let provider: String
  public let providerImage: URL?
  public let wallet: String
  public let apyPercent: String
  public let amount: String?
  public let amountConverted: LoadableModelItem<String?>
  public let fee: LoadableModelItem<String>
  public let feeConverted: LoadableModelItem<String?>
}

public enum StakingOperation {
  case stake
  case unstake
}
