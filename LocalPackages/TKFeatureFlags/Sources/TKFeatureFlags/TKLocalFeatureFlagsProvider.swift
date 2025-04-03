import Foundation
import FirebaseRemoteConfig

public enum LocalFeatureFlag: String, CaseIterable {
  case isTonkeeperSwapOn
  case isConfirmButtonInsteadSlider
  
  var key: String {
    self.rawValue
  }
}

public protocol TKLocalFeatureFlagsProvider: AnyObject {
  var isTonkeeperSwapOn: Bool { get set }
  var isConfirmButtonInsteadSlider: Bool { get set }
  func addObserver<T: AnyObject>(_ observer: T, flags: Set<LocalFeatureFlag>, closure: @escaping (T, LocalFeatureFlag) -> Void)
}

final class UserDefaultsLocalFeatureFlagsProvider: TKLocalFeatureFlagsProvider {
  private let userDefault: UserDefaults
  
  private var observers = [LocalFeatureFlag: [UUID: (LocalFeatureFlag) -> Void]]()
  
  init() {
    self.userDefault = UserDefaults(suiteName: "featureFlags.tkFeatureFlags.tonkeeper") ?? .standard
  }
  
  var isTonkeeperSwapOn: Bool {
    get {
      userDefault.bool(forKey: LocalFeatureFlag.isTonkeeperSwapOn.key)
    }
    set {
      userDefault.setValue(newValue, forKey: LocalFeatureFlag.isTonkeeperSwapOn.key)
    }
  }
  
  var isConfirmButtonInsteadSlider: Bool {
    get {
      userDefault.bool(forKey: LocalFeatureFlag.isConfirmButtonInsteadSlider.key)
    }
    set {
      userDefault.setValue(newValue, forKey: LocalFeatureFlag.isConfirmButtonInsteadSlider.key)
    }
  }
  
  func addObserver<T: AnyObject>(_ observer: T, flags: Set<LocalFeatureFlag>, closure: @escaping (T, LocalFeatureFlag) -> Void) {
    let id = UUID()
    let closure: (LocalFeatureFlag) -> Void = { [weak self, weak observer] flag in
      guard let self else { return }
      var flagObservers = observers[flag]
      guard let observer else {
        flagObservers?.removeValue(forKey: id)
        observers[flag] = flagObservers
        return
      }
      closure(observer, flag)
    }
    let action = {
      for flag in flags {
        var flagObservers = self.observers[flag] ?? [UUID: (LocalFeatureFlag) -> Void]()
        flagObservers[id] = closure
        self.observers[flag] = flagObservers
      }
    }
    if Thread.isMainThread {
      action()
    } else {
      DispatchQueue.main.async {
        action()
      }
    }
  }
}
