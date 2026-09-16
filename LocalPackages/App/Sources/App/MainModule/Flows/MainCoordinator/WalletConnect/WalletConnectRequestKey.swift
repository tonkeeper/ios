import Foundation
import KeeperCore

struct WalletConnectRequestKey: Hashable {
    let id: String
    let topic: String

    init(id: String, topic: String) {
        self.id = id
        self.topic = topic
    }

    init(_ request: WalletConnectSessionRequest) {
        self.init(id: request.id, topic: request.topic)
    }
}
