import Foundation

public final class FeatureFlagsProvider {
  
  public var didUpdateIsMarketRegionPickerAvailable: (() -> Void)?
  public var isMarketRegionPickerAvailable: Bool {
    get {
      firebaseConfigurator.isMarketRegionPickerAvailable
    }
  }
  public var didUpdateIsBuySellLovely: (() -> Void)?
  public var isBuySellLovely: Bool {
    get {
      firebaseConfigurator.isBuySellLovely
    }
  }
  
  private let firebaseConfigurator: FirebaseConfigurator
  
  init(firebaseConfigurator: FirebaseConfigurator) {
    self.firebaseConfigurator = firebaseConfigurator
    firebaseConfigurator.remoteConfig.addOnConfigUpdateListener { [weak self] update, error in
      guard let update else { return }
      for key in update.updatedKeys {
        switch key {
        case FirebaseConfigurator.RemoteValueKeys.isMarketRegionPickerAvailable.rawValue:
          self?.didUpdateIsMarketRegionPickerAvailable?()
        case FirebaseConfigurator.RemoteValueKeys.isBuySellLovely.rawValue:
          self?.didUpdateIsBuySellLovely?()
        default:
          continue
        }
      }
    }
  }
}
