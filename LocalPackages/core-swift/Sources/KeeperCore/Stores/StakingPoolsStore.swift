import Foundation

public final class StakingPoolsStore: StoreV3<StakingPoolsStore.Event, StakingPoolsStore.State> {
  public typealias State = [Wallet: [StackingPoolInfo]]
  
  public enum Event {
    case didUpdateStakingPools(stakingPools: [StackingPoolInfo], wallet: Wallet)
  }
  
  private let walletsStore: WalletsStore
  private let repository: StakingPoolsInfoRepository
  
  init(walletsStore: WalletsStore,
       repository: StakingPoolsInfoRepository) {
    self.walletsStore = walletsStore
    self.repository = repository
    super.init(state: [:])
  }
  
  public override var initialState: State {
    let wallets = walletsStore.wallets
    var state = State()
    wallets.forEach { wallet in
      let walletState = repository.getStakingPoolsInfo(wallet: wallet)
      state[wallet] = walletState
    }
    return state
  }
  
  public func setStackingPools(_ pools: [StackingPoolInfo], wallet: Wallet) async {
    await setState { [repository] state in
      var updatedState = state
      updatedState[wallet] = pools
      try? repository.setStakingPoolsInfo(pools, wallet: wallet)
      return StateUpdate(newState: updatedState)
    } notify: { _ in
      self.sendEvent(.didUpdateStakingPools(stakingPools: pools, wallet: wallet))
    }
  }
}
