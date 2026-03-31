import Foundation

struct BatteryAPIProvider {
    var api: (_ network: Network) -> BatteryAPI?
}
