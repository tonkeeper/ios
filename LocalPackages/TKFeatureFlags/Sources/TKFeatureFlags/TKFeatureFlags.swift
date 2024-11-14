import Foundation

public enum TKFeatureFlags {
  public static let provider: TKFeatureFlagsProvider = {
    FirebaseFeatureFlagsProvider()
  }()
}
