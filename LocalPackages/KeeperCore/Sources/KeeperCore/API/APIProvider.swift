import Foundation
import TonStreamingAPIV2

struct APIProvider {
    var api: (_ network: Network) -> API
}

struct StreamingAPIV2Provider {
    var api: (_ network: Network) async throws -> TonStreamingAPIV2.StreamingAPI?
}
