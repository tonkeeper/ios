import Foundation
import TKUIKit
import BigInt
import TonSwift

struct StakingPoolsMapper {
  func mapToPoolType(
    stakingPools: [StakingPool]
  ) -> StakingOptionsListModel.PoolImplementation? {
    guard let profitablePool = stakingPools.mostProfitablePool else {
      return nil
    }
    
    let isSingle = stakingPools.count == 1
    let address: Address? = isSingle ? profitablePool.address : nil
    
    return .init(
      name: profitablePool.implementation.name,
      image: .fromResource,
      apy: profitablePool.apy,
      minDepositAmount: BigInt(integerLiteral: profitablePool.minStake),
      address: address,
      kind: profitablePool.implementation.type
    )
  }
}
