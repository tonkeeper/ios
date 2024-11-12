import Foundation
import BigInt

public enum BatteryState {
  case fill(percents: CGFloat)
  case empty
  
  public var percents: CGFloat {
    switch self {
    case .fill(let percents):
      return percents
    case .empty:
      return 0
    }
  }
}

public extension BatteryBalance {
  var batteryState: BatteryState {

    let numberFormatter = NumberFormatter()
    numberFormatter.decimalSeparator = "."
    guard let balanceNumber = numberFormatter.number(from: balance) else {
      return .empty
    }
    let balance = CGFloat(truncating: balanceNumber)
    let max = 1.0
    let empty = 0.0
    
    if balance > empty {
      return .fill(percents: balance / max)
    }
    
    return .empty
  }
}
