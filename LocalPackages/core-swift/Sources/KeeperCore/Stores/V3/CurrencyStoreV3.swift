import Foundation

public final class CurrencyStoreV3: StoreV3<CurrencyStoreV3.Event, Currency> {
  public enum Event {
    case didUpdateCurrency(currency: Currency)
  }
  
  private let keeperInfoStore: KeeperInfoStoreV3
  
  public override var initialState: Currency {
    getState(keeperInfo: keeperInfoStore.getState())
  }
  
  init(keeperInfoStore: KeeperInfoStoreV3) {
    self.keeperInfoStore = keeperInfoStore
    super.init(state: .defaultCurrency)
  }
  
  public func setCurrency(_ currency: Currency) async {
    await keeperInfoStore.updateKeeperInfo { keeperInfo in
      let updated = keeperInfo?.setCurrency(currency)
      return updated
    }
    await self.setState { _ in
      return StateUpdate(newState: currency)
    } notify: {
      self.sendEvent(.didUpdateCurrency(currency: currency))
    }
  }
  
  private func getState(keeperInfo: KeeperInfo?) -> Currency {
    if let keeperInfo = keeperInfoStore.getState() {
      return keeperInfo.currency
    } else {
      return .defaultCurrency
    }
  }
}
