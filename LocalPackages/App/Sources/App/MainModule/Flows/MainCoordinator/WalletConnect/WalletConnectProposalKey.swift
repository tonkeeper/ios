import Foundation
import KeeperCore

struct WalletConnectProposalKey: Hashable {
    let id: String
    let pairingTopic: String

    init(id: String, pairingTopic: String) {
        self.id = id
        self.pairingTopic = pairingTopic
    }

    init(_ proposal: WalletConnectSessionProposal) {
        self.init(id: proposal.id, pairingTopic: proposal.pairingTopic)
    }
}
