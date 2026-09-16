import Foundation
import KeeperCore

enum WalletConnectPresentationKey: Hashable {
    case proposal(WalletConnectProposalKey)
    case request(WalletConnectRequestKey)
}

enum WalletConnectPresentationItem: Equatable {
    case proposal(WalletConnectSessionProposal)
    case request(WalletConnectSessionRequest)

    var key: WalletConnectPresentationKey {
        switch self {
        case let .proposal(proposal):
            return .proposal(WalletConnectProposalKey(proposal))
        case let .request(request):
            return .request(WalletConnectRequestKey(request))
        }
    }
}
