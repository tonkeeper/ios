import Foundation
import TonSwift

public final class StakingPoolsStore: Store<[FriendlyAddress: [StackingPoolInfo]]> {
  
  init() {
    super.init(state: [:])
  }
  
  public func getStackingPools(address: FriendlyAddress) async -> [StackingPoolInfo] {
    let state = await getState()
    let pools = state[address]
    return pools ?? []
  }
  
  public func setStackingPools(pools: [StackingPoolInfo], address: FriendlyAddress) async {
    await updateState { state in
      var state = state
      state[address] = pools
      return StateUpdate(newState: state)
    }
  }
}
