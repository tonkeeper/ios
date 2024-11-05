import Foundation

public final class StakingPoolsStore: Store<StakingPoolsStore.Event, StakingPoolsStore.State> {
  public typealias State = [Wallet: [StackingPoolInfo]]
  
  public enum Event {
    case didUpdateStakingPools(wallet: Wallet)
  }
  
  private let walletsStore: WalletsStore
  private let repository: StakingPoolsInfoRepository
  
  init(walletsStore: WalletsStore,
       repository: StakingPoolsInfoRepository) {
    self.walletsStore = walletsStore
    self.repository = repository
    super.init(state: [:])
  }
  
  public override func createInitialState() -> State {
    let wallets = walletsStore.wallets
    var state = State()
    wallets.forEach { wallet in
      let walletState = repository.getStakingPoolsInfo(wallet: wallet)
      state[wallet] = walletState
    }
    return state
  }
  
  public func setStackingPools(_ pools: [StackingPoolInfo],
                               wallet: Wallet) async {
    return await withCheckedContinuation { continuation in
      setStackingPools(pools, wallet: wallet) {
        continuation.resume()
      }
    }
  }
  
  public func setStackingPools(_ pools: [StackingPoolInfo],
                               wallet: Wallet,
                               completion: @escaping () -> Void) {
    updateState { [repository] state in
      var updatedState = state
      updatedState[wallet] = pools
      try? repository.setStakingPoolsInfo(pools, wallet: wallet)
      return StateUpdate(newState: updatedState)
    } completion: { [weak self] _ in
      self?.sendEvent(.didUpdateStakingPools(wallet: wallet))
      completion()
    }
  }
}
