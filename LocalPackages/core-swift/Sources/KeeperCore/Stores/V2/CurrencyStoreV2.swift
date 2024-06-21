import Foundation

public final class CurrencyStoreV2: Store<Currency> {
  
  private let keeperInfoStore: KeeperInfoStore
  
  init(keeperInfoStore: KeeperInfoStore) {
    self.keeperInfoStore = keeperInfoStore
    super.init(item: .USD)
    keeperInfoStore.addObserver(self, notifyOnAdded: true) { observer, keeperInfo in
      observer.didUpdateKeeperInfo(keeperInfo)
    }
  }
 
  public func getCurrency() async -> Currency {
    await getItem()
  }
  
  public func setCurrency(_ currency: Currency) async {
    await updateItem { _ in
      return currency
    }
    await keeperInfoStore.updateItem { keeperInfo in
      guard let keeperInfo else { return keeperInfo }
      let updatedKeeperInfo = keeperInfo.setCurrency(currency)
      return updatedKeeperInfo
    }
  }
}

private extension CurrencyStoreV2 {
  func didUpdateKeeperInfo(_ keeperInfo: KeeperInfo?) {
    guard let keeperInfo else { return }
    Task {
      await updateItem { state in
        guard state != keeperInfo.currency else { return state }
        return keeperInfo.currency
      }
    }
  }
}
