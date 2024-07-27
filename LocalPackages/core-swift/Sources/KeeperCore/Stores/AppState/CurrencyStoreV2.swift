import Foundation

public final class CurrencyStoreV2: StoreUpdated<Currency> {
  
  private let keeperInfoStore: KeeperInfoStore
  
  init(keeperInfoStore: KeeperInfoStore) {
    self.keeperInfoStore = keeperInfoStore
    super.init(state: .defaultCurrency)
    keeperInfoStore.addObserver(self, notifyOnAdded: false) { observer, keeperInfo, oldKeeperInfo in
      guard keeperInfo?.currency != oldKeeperInfo?.currency else { return }
      observer.didUpdateKeeperInfo(keeperInfo)
    }
  }
  
  public func getCurrency() -> Currency {
    keeperInfoStore.getState()?.currency ?? .defaultCurrency
  }
  
  public func getCurrency() async -> Currency {
    await keeperInfoStore.getState()?.currency ?? .defaultCurrency
  }
  
  public func setCurrency(_ currency: Currency, completion: (() -> Void)? = nil) {
    keeperInfoStore.updateKeeperInfo { keeperInfo in
      return keeperInfo?.setCurrency(currency)
    } completion: { [weak self] in
      guard let self else { return }
      updateState { _ in
        StateUpdate(newState: currency)
      } completion: {
        completion?()
      }
    }
  }
  
  public func setCurrency(_ currency: Currency) async {
    await keeperInfoStore.updateKeeperInfo { keeperInfo in
      return keeperInfo?.setCurrency(currency)
    }
    await updateState { _ in
      StateUpdate(newState: currency)
    }
  }

  public override func getInitialState() -> Currency {
    keeperInfoStore.getState()?.currency ?? .defaultCurrency
  }
  
  private func didUpdateKeeperInfo(_ keeperInfo: KeeperInfo?) {
    updateState { _ in
      StateUpdate(newState: keeperInfo?.currency ?? .defaultCurrency)
    }
  }
}
