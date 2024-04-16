import Foundation
import FirebaseCore
import FirebaseRemoteConfig

public final class FirebaseConfigurator {
  
  static let configurator = FirebaseConfigurator()
  
  private init() {}
  
  lazy var remoteConfig: RemoteConfig = {
    let remoteConfig = RemoteConfig.remoteConfig()
    let settings = RemoteConfigSettings()
    settings.minimumFetchInterval = 0
    remoteConfig.configSettings = settings
    return remoteConfig
  }()
  
  public func configure() {
    FirebaseApp.configure()
    
    configureRemoteConfig()
  }
  
  public var isMarketRegionPickerAvailable: Bool {
    remoteConfig
      .configValue(forKey: FirebaseConfigurator.RemoteValueKeys.isMarketRegionPickerAvailable.rawValue)
      .boolValue
  }

  private func configureRemoteConfig() {
    do {
      try remoteConfig.setDefaults(
        from: [
          RemoteValueKeys.isMarketRegionPickerAvailable.rawValue: false
        ]
      )
    } catch {
      print("Firebase Remote Config: failed to set defaults values")
    }
    Task {
      do {
        try await remoteConfig.fetch()
        try await remoteConfig.activate()
      } catch {
        print("Firebase Remote Config: \(error)")
      }
    }
  }
}

extension FirebaseConfigurator {
  enum RemoteValueKeys: String {
    case isMarketRegionPickerAvailable = "isMarketRegionPickerAvailable"
  }
}
