import Foundation
import TKUIKit
import BigInt
import TonSwift

public final class StakingOptionsListMapper {
  private let amountFormatter: AmountFormatter
  private let decimalFormatter: DecimalAmountFormatter
  
  init(amountFormatter: AmountFormatter, decimalFormatter: DecimalAmountFormatter) {
    self.amountFormatter = amountFormatter
    self.decimalFormatter = decimalFormatter
  }
  
  func mapPoolImplementations(
    _ poolImplementations: [StakingOptionsListModel.PoolImplementation],
    selectedPoolAddress: Address?,
    mostPofitableId: String?
  ) -> [StakingOptionItem] {
    return poolImplementations.map {
      let address = $0.address
      let isSelected = address == selectedPoolAddress
      let apy = decimalFormatter.format(amount: $0.apy, maximumFractionDigits: 2)
      let minDepoAmount = amountFormatter.formatAmount(
        BigInt($0.minDepositAmount),
        fractionDigits: Token.ton.fractionDigits,
        maximumFractionDigits: Token.ton.fractionDigits
      )
      
      return .init(
        id: $0.name,
        title: $0.name,
        image: .fromResource,
        apyPercents: "\(apy)%",
        apyTokenAmount: nil,
        isMaxAPY: mostPofitableId == $0.name,
        minDepositAmount: "\(minDepoAmount) \(Token.ton.symbol)",
        canSelect: address != nil,
        isSelected: isSelected,
        kind: $0.kind
      )
    }
  }
  
  func mapStakingPools(
    _ pools: [StakingPool],
    profitablePool: StakingPool,
    selectedPoolAddress: Address?
  ) -> [StakingOptionItem] {
    return pools
      .sorted(by: { $0.apy > $1.apy })
      .map {
        let address = $0.address
        let isSelected = $0.address == selectedPoolAddress
        let apy = decimalFormatter.format(amount: $0.apy, maximumFractionDigits: 2)
        let minDepoAmount = amountFormatter.formatAmount(
          BigInt($0.minStake),
          fractionDigits: Token.ton.fractionDigits,
          maximumFractionDigits: Token.ton.fractionDigits
        )
        
        return .init(
          id: $0.address.toRaw(),
          title: $0.name,
          image: .fromResource,
          apyPercents: "\(apy)%",
          apyTokenAmount: nil,
          isMaxAPY: address == profitablePool.address,
          minDepositAmount: "\(minDepoAmount) \(Token.ton.symbol)",
          canSelect: true,
          isSelected: isSelected,
          kind: $0.implementation.type
        )
      }
  }
}


