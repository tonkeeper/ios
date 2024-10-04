import Foundation

public extension JettonInfo {
  var tag: String? {
    switch address {
    case JettonMasterAddress.tonUSDT:
      return "TON"
    default:
      return nil
    }
  }
}
