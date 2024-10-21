import Foundation

public final class CurrencyStore: Store<CurrencyStore.Event, Currency> {
  public enum Event {
    case didUpdateCurrency(currency: Currency)
  }
  
  private let keeperInfoStore: KeeperInfoStore
  
  public override func createInitialState() -> Currency {
    getState(keeperInfo: keeperInfoStore.getState())
  }
  
  init(keeperInfoStore: KeeperInfoStore) {
    self.keeperInfoStore = keeperInfoStore
    super.init(state: .defaultCurrency)
  }
  
  @discardableResult
  public func setCurrency(_ currency: Currency) async -> Currency {
    return await withCheckedContinuation { continuation in
      setCurrency(currency) { currency in
        continuation.resume(returning: currency)
      }
    }
  }
  
  public func setCurrency(_ currency: Currency,
                          completion: @escaping (Currency) -> Void) {
    keeperInfoStore.updateKeeperInfo { keeperInfo in
      let updateKeeperInfo = keeperInfo?.updateCurrency(currency)
      return updateKeeperInfo
    } completion: { [weak self] keeperInfo in
      guard let self else { return }
      let state = self.getState(keeperInfo: keeperInfo)
      updateState { _ in
        return StateUpdate(newState: state)
      } completion: { [weak self] state in
        self?.sendEvent(.didUpdateCurrency(currency: state))
        completion(state)
      }
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
