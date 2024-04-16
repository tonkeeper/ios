import Foundation

public struct FeatureFlagsProvider {
  
  public init(isMarketRegionPickerAvailable: @escaping () async -> Bool = { false }) {
    self.isMarketRegionPickerAvailable = isMarketRegionPickerAvailable
  }
  
  public var isMarketRegionPickerAvailable: () async -> Bool
}
