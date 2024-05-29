import Foundation

public struct FeatureFlagsProvider {
  
  public init(isMarketRegionPickerAvailable: @escaping () async -> Bool = { false },
              isBuySellLovely: @escaping () async -> Bool = { false }) {
    self.isMarketRegionPickerAvailable = isMarketRegionPickerAvailable
    self.isBuySellLovely = isBuySellLovely
  }
  
  public var isMarketRegionPickerAvailable: () async -> Bool
  
  public var isBuySellLovely: () async -> Bool
}
