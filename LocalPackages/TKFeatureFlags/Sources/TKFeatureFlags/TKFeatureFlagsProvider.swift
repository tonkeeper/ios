import Foundation
import FirebaseRemoteConfig

public enum FeatureFlag: String, CaseIterable {
  case isSwapDisable
  case isExchangeMethodsDisable
  case isDappsDisable
  case isStoriesDisable
  case disableBatteryCryptoRechargeModule
  
  var key: String {
    self.rawValue
  }
}

public protocol TKFeatureFlagsProvider {
  var isSwapDisable: Bool { get }
  var isExchangeMethodsDisable: Bool { get }
  var isDappsDisable: Bool { get }
  var isStoriesDisable: Bool { get }
  var isBatteryCryptoRechargeDisable: Bool { get }
  
  func addObserver<T: AnyObject>(_ observer: T, flags: Set<FeatureFlag>, closure: @escaping (T, FeatureFlag) -> Void)
}

final class FirebaseFeatureFlagsProvider: TKFeatureFlagsProvider {
  var isSwapDisable: Bool {
    RemoteConfig.remoteConfig().configValue(forKey: FeatureFlag.isSwapDisable.key).boolValue
  }
  var isExchangeMethodsDisable: Bool {
    RemoteConfig.remoteConfig().configValue(forKey: FeatureFlag.isExchangeMethodsDisable.key).boolValue
  }
  var isDappsDisable: Bool {
    RemoteConfig.remoteConfig().configValue(forKey: FeatureFlag.isDappsDisable.key).boolValue
  }
  var isBatteryCryptoRechargeDisable: Bool {
    RemoteConfig.remoteConfig().configValue(forKey: FeatureFlag.disableBatteryCryptoRechargeModule.key).boolValue
  }
  var isStoriesDisable: Bool {
    RemoteConfig.remoteConfig().configValue(forKey: FeatureFlag.isStoriesDisable.key).boolValue
  }
  
  private var observers = [FeatureFlag: [UUID: (FeatureFlag) -> Void]]()
  
  init() {
    let remoteConfig = RemoteConfig.remoteConfig()
    let settings = RemoteConfigSettings()
    settings.minimumFetchInterval = 0
    remoteConfig.configSettings = settings
    
    remoteConfig.setDefaults([FeatureFlag.isSwapDisable.key: "true" as NSString,
                              FeatureFlag.isExchangeMethodsDisable.key: "true" as NSString,
                              FeatureFlag.isDappsDisable.key: "true" as NSString,
                              FeatureFlag.isStoriesDisable.key: "true" as NSString,
                              FeatureFlag.disableBatteryCryptoRechargeModule.key: "true" as NSString])
    
    remoteConfig.fetch { [weak self] status, error in
      if status == .success {
        self?.activate(updatedKeys: nil)
      } else {
        print("🔥 Firebase config not fetched")
        print("🔥 Error: \(error?.localizedDescription ?? "No error available.")")
      }
    }
  
    remoteConfig.addOnConfigUpdateListener { [weak self] configUpdate, error in
      guard let configUpdate, error == nil else {
        print("🔥 Error listening for config updates: \(error?.localizedDescription ?? "No error available.")")
        return
      }

      print("🔥 Updated keys: \(configUpdate.updatedKeys)")
      self?.activate(updatedKeys: configUpdate.updatedKeys)
    }
  }
  
  func addObserver<T: AnyObject>(_ observer: T, flags: Set<FeatureFlag>, closure: @escaping (T, FeatureFlag) -> Void) {
    let id = UUID()
    let closure: (FeatureFlag) -> Void = { [weak self, weak observer] flag in
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
        var flagObservers = self.observers[flag] ?? [UUID: (FeatureFlag) -> Void]()
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
  
  func activate(updatedKeys: Set<String>?) {
    let remoteConfig = RemoteConfig.remoteConfig()
    remoteConfig.activate { [weak self] changed, error in
      guard let self else { return }
      let action = {
        guard error == nil else {
          print("🔥 Error activate: \(error?.localizedDescription ?? "No error available.")")
          return
        }
        
        guard changed else { return }
        
        let updatedFlags: [FeatureFlag] = {
          if let updatedKeys {
            return updatedKeys.compactMap { FeatureFlag(rawValue: $0) }
          } else {
            return FeatureFlag.allCases
          }
        }()
        
        updatedFlags.forEach { flag in
          self.observers[flag]?.forEach { $0.value(flag) }
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
}

