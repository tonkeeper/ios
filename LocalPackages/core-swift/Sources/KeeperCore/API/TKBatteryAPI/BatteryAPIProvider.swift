import Foundation

struct BatteryAPIProvider {
  var api: (_ isTestnet: Bool) -> BatteryAPI
}
