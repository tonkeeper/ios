import Foundation
import TKUIKit
import BigInt
import TonSwift

public struct StakingOptionDetailItem {
  public let name: String
  public let apy: String
  public let minDeposit: String
}

public final class StakingOptionsDetailsController {
  public var didUpdateItem: ((StakingOptionDetailItem) -> Void)?
  public let stakingPool: StakingPool
  
  private let amountFormatter: AmountFormatter
  private let decimalFormatter: DecimalAmountFormatter
  
  init(
    stakingPool: StakingPool,
    amountFormatter: AmountFormatter,
    decimalFormatter: DecimalAmountFormatter
  ) {
    self.stakingPool = stakingPool
    self.amountFormatter = amountFormatter
    self.decimalFormatter = decimalFormatter
  }
  
  public func start() {
    updateItem()
  }
}

// MARK: - Private methods

extension StakingOptionsDetailsController {
  func updateItem() {
    let apy = decimalFormatter.format(amount: stakingPool.apy, maximumFractionDigits: 2)
    let minDepoAmount = amountFormatter.formatAmount(
      BigInt(stakingPool.minStake),
      fractionDigits: Token.ton.fractionDigits,
      maximumFractionDigits: Token.ton.fractionDigits
    )
    
    let item = StakingOptionDetailItem(
      name: stakingPool.name,
      apy: "\(apy)%",
      minDeposit: "\(minDepoAmount) \(Token.ton.symbol)"
    )
    
    didUpdateItem?(item)
  }
}
