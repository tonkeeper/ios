import Foundation

public final class StakingPoolsStore: StoreV3<StakingPoolsStore.Event, StakingPoolsStore.State> {
  public typealias State = [Wallet: [StackingPoolInfo]]
  
  public enum Event {
    case didUpdateStakingPools(stakingPools: [StackingPoolInfo], wallet: Wallet)
  }
  
  init() {
    super.init(state: [:])
  }
  
  public override var initialState: State {
    [:]
  }
  
  public func setStackingPools(_ pools: [StackingPoolInfo], wallet: Wallet) async {
    await setState { state in
      var updatedState = state
      updatedState[wallet] = pools
      return StateUpdate(newState: updatedState)
    } notify: { _ in
      self.sendEvent(.didUpdateStakingPools(stakingPools: pools, wallet: wallet))
    }
  }
}
