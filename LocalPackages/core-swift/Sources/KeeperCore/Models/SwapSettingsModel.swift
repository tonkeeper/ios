import Foundation

public struct SwapSettingsModel {
  public let slippageTolerance: SlippageTolerance
  
  public init(slippageTolerance: SlippageTolerance) {
    self.slippageTolerance = slippageTolerance
  }
}

public struct SlippageTolerance {
  public let percent: Decimal
  public var converted: String {
    "\(percent * 0.01)"
  }
  
  public init(percent: Decimal) {
    self.percent = percent
  }
}

extension SwapSettingsModel {
  public init() {
    self.slippageTolerance = SlippageTolerance(
      percent: 1
    )
  }
}
