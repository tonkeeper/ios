import Foundation

public final class CurrencyStoreV2: Store<Currency> {
  
  private let keeperInfoStore: KeeperInfoStore
  
  init(keeperInfoStore: KeeperInfoStore) {
    self.keeperInfoStore = keeperInfoStore
    super.init(state: .USD)
    keeperInfoStore.addObserver(self, notifyOnAdded: true) { observer, keeperInfo, _ in
      observer.didUpdateKeeperInfo(keeperInfo)
    }
  }
  
  public func getCurrency() async -> Currency {
    await getState()
  }
  
  public func setCurrency(_ currency: Currency) async {
    await updateState { _ in StateUpdate(newState: currency) }
    await keeperInfoStore.updateKeeperInfo { keeperInfo in
      let updatedKeeperInfo = keeperInfo?.setCurrency(currency)
      return updatedKeeperInfo
    }
  }
}

private extension CurrencyStoreV2 {
  func didUpdateKeeperInfo(_ keeperInfo: KeeperInfo?) {
    guard let keeperInfo else { return }
    Task {
      await updateState { _ in
        return StateUpdate(newState: keeperInfo.currency)
      }
    }
  }
}
