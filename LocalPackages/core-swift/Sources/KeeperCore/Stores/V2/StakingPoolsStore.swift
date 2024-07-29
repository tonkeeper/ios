import Foundation
import TonSwift

public final class StakingPoolsStore: StoreUpdated<[FriendlyAddress: [StackingPoolInfo]]> {
  
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
  
  public override func getInitialState() -> [FriendlyAddress : [StackingPoolInfo]] {
    [:]
  }
}
