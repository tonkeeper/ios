import Foundation
import TonSwift

public struct WalletBalanceItemsModel {
  public let tonItems: [Item]
  public let jettonsItems: [Item]
  
  public init(tonItems: [Item], jettonsItems: [Item]) {
    self.tonItems = tonItems
    self.jettonsItems = jettonsItems
  }
}

public extension WalletBalanceItemsModel {
  enum StakingInfo {
    case none
    case pool(StakingPoolItem)
  }
  
  struct Item {
    public let identifier: String
    public let token: Token
    public let image: TokenImage
    public let title: String
    public let price: String?
    public let rateDiff: String?
    public let amount: String?
    public let convertedAmount: String?
    public let verification: JettonInfo.Verification
    public let hasPrice: Bool
    public let stakingInfo: StakingInfo
  }
  
  struct StakingPoolItem {
    public let name: String
    public let depositToken: Token
    public let poolType: StakingPool.Implementation.Kind
  }
}
