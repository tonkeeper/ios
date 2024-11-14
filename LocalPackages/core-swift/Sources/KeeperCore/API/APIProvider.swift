import Foundation
import TonStreamingAPI

struct APIProvider {
  var api: (_ isTestnet: Bool) -> API
}

struct StreamingAPIProvider {
  var api: (_ isTestnet: Bool) -> StreamingAPI
}
