import Foundation
import KeeperCore

enum BatteryIAPPack: String, CaseIterable {
  case large = "LargePack"
  case medium = "MediumPack"
  case small = "SmallPack"
  
  var productIdentifier: String {
    rawValue
  }
  
  var name: String {
    switch self {
    case .large:
      "Large"
    case .medium:
      "Medium"
    case .small:
      "Small"
    }
  }
  
  var batteryPercent: CGFloat {
    switch self {
    case .large:
      return 1
    case .medium:
      return 0.5
    case .small:
      return 0.3
    }
  }
  
  var userProceed: Decimal {
    switch self {
    case .large:
      return 7.5
    case .medium:
      return 5
    case .small:
      return 2.5
    }
  }
}

struct BatteryIAPItem {
  struct Amount {
    let price: Decimal
    let currency: Currency
    let charges: Int
  }
  enum State {
    case loading
    case amount(Amount)
  }
  
  let pack: BatteryIAPPack
  let isEnable: Bool
  let state: State
}
