import Foundation

final class WalletConnectState {
    var eventsLoop: WalletConnectEventsLoop?
    var pairingTopics = Set<String>()
    var presentationQueue = WalletConnectPresentationQueue()
    var proposalCoordinators = [WalletConnectProposalKey: WalletConnectProposal]()
    var requestCoordinators = [WalletConnectRequestKey: WalletConnectRequest]()

    func cancel() {
        eventsLoop?.cancel()
    }
}
