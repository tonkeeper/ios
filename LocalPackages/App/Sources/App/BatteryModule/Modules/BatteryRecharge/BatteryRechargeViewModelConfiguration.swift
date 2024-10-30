import Foundation

struct BatteryRechargeViewModelConfiguration {
  
  var title: String {
    isGift ? "Gift" : "Recharge"
  }
  
  let isGift: Bool
}
