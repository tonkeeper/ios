import Foundation
import TonConnectAPI

struct TonConnectBridgeAPIClientProvider {
    var tonConnectBridgerAPIClient: () async -> TonConnectAPI.Client
}
