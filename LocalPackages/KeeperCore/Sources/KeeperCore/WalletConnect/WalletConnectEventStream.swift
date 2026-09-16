import Combine
import Foundation
@preconcurrency import ReownWalletKit
import TKLogging

enum WalletConnectRawEvent {
    case proposalReceived(WalletConnectProposalContext)
    case proposalExpired(Session.Proposal)

    case requestReceived(Request, context: VerifyContext?)
    case requestExpired(RPCID)

    case sessionSettled(_ session: Session)
    case sessionDeleted(topic: String, reason: Reason)
}

struct WalletConnectProposalContext {
    var id: String
    var pairingTopic: String
    var dapp: WalletConnectDapp
    var validation: WalletConnectValidation
    var requiredNamespaces: [String: ProposalNamespace]
    var optionalNamespaces: [String: ProposalNamespace]?
}

extension WalletConnectProposalContext {
    init(
        proposal: Session.Proposal,
        context: VerifyContext?,
        namespaceBuilder: WalletConnectSessionNamespaceBuilder = WalletConnectSessionNamespaceBuilder()
    ) {
        self.init(
            id: proposal.id,
            pairingTopic: proposal.pairingTopic,
            dapp: WalletConnectDapp(metadata: proposal.proposer),
            validation: WalletConnectValidation(context: context),
            requiredNamespaces: proposal.requiredNamespaces,
            optionalNamespaces: proposal.optionalNamespaces
        )
    }

    func proposal(
        source: DappConnectionSource,
        namespaceBuilder: WalletConnectSessionNamespaceBuilder = WalletConnectSessionNamespaceBuilder()
    ) -> WalletConnectSessionProposal {
        WalletConnectSessionProposal(
            id: id,
            pairingTopic: pairingTopic,
            dapp: dapp,
            namespaces: namespaceBuilder.proposalNamespaces(
                requiredNamespaces: requiredNamespaces,
                optionalNamespaces: optionalNamespaces
            ),
            validation: validation,
            source: source
        )
    }
}

@WalletConnectActor
final class WalletConnectEventStream: Sendable {
    nonisolated let stream: AsyncStream<WalletConnectRawEvent>

    private let continuation: AsyncStream<WalletConnectRawEvent>.Continuation

    private let subscribeToWalletKit: Bool
    private var cancellables = Set<AnyCancellable>()
    private var hasSubscribed: Bool

    init(subscribeToWalletKit: Bool = true) {
        (stream, continuation) = AsyncStream<WalletConnectRawEvent>.makeStream()
        self.subscribeToWalletKit = subscribeToWalletKit
        hasSubscribed = false
    }
}

extension WalletConnectEventStream {
    func subscribe() {
        guard !hasSubscribed else {
            return Log.walletConnect.w(
                "stream is already subscribed to wallet connect events, skipping"
            )
        }
        hasSubscribed = true
        guard subscribeToWalletKit else {
            return
        }
        Log.walletConnect.i("subscribe to WalletKit events")

        let continuation = continuation
        let emitIfAlive: @Sendable (WalletConnectRawEvent) -> Void = { [weak self, continuation] event in
            guard self != nil else {
                return
            }
            continuation.yield(event)
        }

        WalletKit.instance.sessionProposalPublisher
            .map { proposal, context in
                WalletConnectRawEvent.proposalReceived(
                    WalletConnectProposalContext(
                        proposal: proposal,
                        context: context
                    )
                )
            }
            .sink(receiveValue: emitIfAlive)
            .store(in: &cancellables)

        WalletKit.instance.sessionProposalExpirationPublisher
            .map(WalletConnectRawEvent.proposalExpired)
            .sink(receiveValue: emitIfAlive)
            .store(in: &cancellables)

        WalletKit.instance.sessionRequestPublisher
            .map(WalletConnectRawEvent.requestReceived)
            .sink(receiveValue: emitIfAlive)
            .store(in: &cancellables)

        WalletKit.instance.requestExpirationPublisher
            .map(WalletConnectRawEvent.requestExpired)
            .sink(receiveValue: emitIfAlive)
            .store(in: &cancellables)

        WalletKit.instance.sessionSettlePublisher
            .map(WalletConnectRawEvent.sessionSettled)
            .sink(receiveValue: emitIfAlive)
            .store(in: &cancellables)

        WalletKit.instance.sessionDeletePublisher
            .map(WalletConnectRawEvent.sessionDeleted)
            .sink(receiveValue: emitIfAlive)
            .store(in: &cancellables)

        WalletKit.instance.logsPublisher
            .sink { log in
                switch log {
                case .debug:
                    Log.walletConnect.d("reown debug")
                case .error:
                    Log.walletConnect.w("reown error", error: WalletConnectSDKLogError())
                case .warn:
                    Log.walletConnect.w("reown warning", error: WalletConnectSDKLogError())
                case .info:
                    Log.walletConnect.i("reown info")
                }
            }
            .store(in: &cancellables)
    }

    func emit(_ event: WalletConnectRawEvent) {
        continuation.yield(event)
    }
}

private struct WalletConnectSDKLogError: LoggableError {
    var logDescription: String {
        "type=WalletConnectSDKLogError, source=Reown"
    }
}
