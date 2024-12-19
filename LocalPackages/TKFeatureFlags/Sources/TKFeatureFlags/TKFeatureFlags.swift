import Foundation

public enum TKFeatureFlags {
  public static let provider: TKFeatureFlagsProvider = {
    FirebaseFeatureFlagsProvider()
  }()
  
  public static let localProvider: TKLocalFeatureFlagsProvider = {
    UserDefaultsLocalFeatureFlagsProvider()
  }()
}
