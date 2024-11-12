import Foundation

public struct BatterySettings: Equatable, Codable {
  public let isSwapTransactionEnable: Bool
  public let isJettonTransactionEnable: Bool
  public let isNFTTransactionEnable: Bool
  
  public init(isSwapTransactionEnable: Bool = true,
              isJettonTransactionEnable: Bool = true,
              isNFTTransactionEnable: Bool = true) {
    self.isSwapTransactionEnable = isSwapTransactionEnable
    self.isJettonTransactionEnable = isJettonTransactionEnable
    self.isNFTTransactionEnable = isNFTTransactionEnable
  }
  
  public func setIsSwapTransactionEnable(isEnable: Bool) -> BatterySettings {
    BatterySettings(
      isSwapTransactionEnable: isEnable,
      isJettonTransactionEnable: self.isJettonTransactionEnable,
      isNFTTransactionEnable: self.isNFTTransactionEnable
    )
  }
  
  public func setIsJettonTransactionEnable(isEnable: Bool) -> BatterySettings {
    BatterySettings(
      isSwapTransactionEnable: self.isSwapTransactionEnable,
      isJettonTransactionEnable: isEnable,
      isNFTTransactionEnable: self.isNFTTransactionEnable
    )
  }
  
  public func setIsNFTTransactionEnable(isEnable: Bool) -> BatterySettings {
    BatterySettings(
      isSwapTransactionEnable: self.isSwapTransactionEnable,
      isJettonTransactionEnable: self.isJettonTransactionEnable,
      isNFTTransactionEnable: isEnable
    )
  }
}
