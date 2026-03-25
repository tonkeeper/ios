import Foundation
import TonStreamingAPI

struct APIProvider {
    var api: (_ network: Network) -> API
}

struct StreamingAPIProvider {
    var api: (_ network: Network) -> StreamingAPI?
}
