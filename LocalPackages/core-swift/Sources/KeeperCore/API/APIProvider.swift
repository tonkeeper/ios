import Foundation

struct APIProvider {
  var api: (_ isTestnet: Bool) -> API
}
