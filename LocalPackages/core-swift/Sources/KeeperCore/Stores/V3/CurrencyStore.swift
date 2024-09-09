import Foundation

public final class CurrencyStore: StoreV3<CurrencyStore.Event, Currency> {
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
    await self.setState { _ in
      return StateUpdate(newState: currency)
    } notify: { state in
      self.sendEvent(.didUpdateCurrency(currency: state))
    }
    await keeperInfoStore.updateKeeperInfo { keeperInfo in
      let updated = keeperInfo?.updateCurrency(currency)
      return updated
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
