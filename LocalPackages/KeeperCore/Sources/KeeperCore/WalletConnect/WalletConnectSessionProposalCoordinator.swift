import Foundation
@preconcurrency import ReownWalletKit
import TKLogging

@WalletConnectActor
final class WalletConnectSessionProposalCoordinator: Sendable {
    private let network: WalletConnectWalletKitClientProtocol
    private let accountResolver: WalletConnectAccountResolver
    private let namespaceBuilder: WalletConnectSessionNamespaceBuilder

    private var pendingProposals = [String: [WalletConnectPendingProposal]]()
    private var receivedProposalKeys = Set<WalletConnectProposalReceiveKey>()

    init(
        network: WalletConnectWalletKitClientProtocol,
        accountResolver: WalletConnectAccountResolver = WalletConnectAccountResolver(),
        namespaceBuilder: WalletConnectSessionNamespaceBuilder = WalletConnectSessionNamespaceBuilder()
    ) {
        self.network = network
        self.accountResolver = accountResolver
        self.namespaceBuilder = namespaceBuilder
    }

    func receive(
        _ proposalContext: WalletConnectProposalContext,
        source: DappConnectionSource
    ) -> WalletConnectSessionProposal? {
        let key = WalletConnectProposalReceiveKey(
            pairingTopic: proposalContext.pairingTopic,
            proposalId: proposalContext.id
        )
        guard receivedProposalKeys.insert(key).inserted else {
            Log.walletConnect.i("duplicate proposal ignored", extraInfo: [
                "proposalId": proposalContext.id,
            ])
            return nil
        }
        let pendingProposal = WalletConnectPendingProposal(
            context: proposalContext,
            source: source
        )
        pendingProposals[pendingProposal.id, default: []].append(pendingProposal)
        return pendingProposal.domain(namespaceBuilder: namespaceBuilder)
    }

    func expire(_ rawProposal: Session.Proposal) -> WalletConnectSessionProposal? {
        guard let pendingProposal = removePendingProposal(
            id: rawProposal.id,
            pairingTopic: rawProposal.pairingTopic
        ) else {
            return nil
        }
        return pendingProposal.domain(namespaceBuilder: namespaceBuilder)
    }

    func approve(
        id: String,
        wallet: Wallet
    ) async throws(WalletConnectSessionApprovalError) -> WalletConnectApprovedProposal {
        let pendingProposal = try requirePendingProposalForApproval(id: id)
        let proposal = pendingProposal.domain(namespaceBuilder: namespaceBuilder)

        guard case .regular = wallet.kind else {
            try await rejectInvalidProposal(
                id: id,
                proposal: proposal,
                error: .unsupportedWalletKind
            )
        }

        do {
            let accounts = try accountResolver.accounts(
                wallet: wallet,
                requiredChains: requiredChains(proposal),
                optionalChains: optionalChains(proposal)
            )
            let namespaces = try namespaceBuilder.sessionNamespaces(
                requiredNamespaces: pendingProposal.requiredNamespaces,
                optionalNamespaces: pendingProposal.optionalNamespaces,
                walletConnectAccounts: accounts
            )
            let session = try await network.approveProposal(
                id: id,
                namespaces: namespaces,
                sessionProperties: namespaceBuilder.sessionProperties(
                    for: namespaces,
                    wallet: wallet
                ),
                scopedProperties: namespaceBuilder.scopedProperties(for: namespaces)
            )
            return WalletConnectApprovedProposal(
                proposal: proposal,
                session: session,
                walletId: wallet.id
            )
        } catch {
            Log.walletConnect.w(
                "proposal approval failed",
                error: error,
                extraInfo: proposalLogInfo(proposal)
            )
            try await handleProposalApprovalFailure(
                id: id,
                proposal: proposal,
                error: error
            )
        }
    }

    func reject(
        id: String
    ) async throws(WalletConnectSessionRejectionError) {
        let pendingProposal = try requirePendingProposalForRejection(id: id)

        do {
            try await network.rejectProposal(
                id: id,
                reason: .userRejected
            )
            clear(pendingProposal)
        } catch {
            if !error.isRetryableDeliveryFailure {
                clear(pendingProposal)
            }
            Log.walletConnect.w(
                "proposal rejection delivery failed",
                error: error,
                extraInfo: [
                    "proposalId": pendingProposal.id,
                ]
            )
            throw error
        }
    }

    func clear(id: String, pairingTopic: String) {
        removePendingProposal(id: id, pairingTopic: pairingTopic)
    }
}

private extension WalletConnectSessionProposalCoordinator {
    func pendingProposal(id: String) -> WalletConnectPendingProposal? {
        pendingProposals[id]?.first
    }

    func clear(_ pendingProposal: WalletConnectPendingProposal) {
        removePendingProposal(
            id: pendingProposal.id,
            pairingTopic: pendingProposal.pairingTopic
        )
    }

    @discardableResult
    func removePendingProposal(
        id: String,
        pairingTopic: String
    ) -> WalletConnectPendingProposal? {
        guard var bucket = pendingProposals[id],
              let index = bucket.firstIndex(where: { $0.pairingTopic == pairingTopic })
        else {
            return nil
        }

        let proposal = bucket.remove(at: index)
        receivedProposalKeys.remove(
            WalletConnectProposalReceiveKey(
                pairingTopic: proposal.pairingTopic,
                proposalId: proposal.id
            )
        )
        if bucket.isEmpty {
            pendingProposals[id] = nil
        } else {
            pendingProposals[id] = bucket
        }
        return proposal
    }

    func requirePendingProposalForApproval(
        id: String
    ) throws(WalletConnectSessionApprovalError) -> WalletConnectPendingProposal {
        guard let proposal = pendingProposal(id: id) else {
            let error = WalletConnectSessionApprovalError.missingProposal(id: id)
            Log.walletConnect.w(
                "proposal approval failed: pending proposal missing",
                error: error,
                extraInfo: ["proposalId": id]
            )
            throw error
        }
        return proposal
    }

    func requirePendingProposalForRejection(
        id: String
    ) throws(WalletConnectSessionRejectionError) -> WalletConnectPendingProposal {
        guard let proposal = pendingProposal(id: id) else {
            let error = WalletConnectSessionRejectionError.missingProposal(id: id)
            Log.walletConnect.w(
                "proposal rejection failed: pending proposal missing",
                error: error,
                extraInfo: ["proposalId": id]
            )
            throw error
        }
        return proposal
    }

    func handleProposalApprovalFailure(
        id: String,
        proposal: WalletConnectSessionProposal,
        error: WalletConnectSessionApprovalError
    ) async throws(WalletConnectSessionApprovalError) -> Never {
        guard !error.isRetryableDeliveryFailure else {
            throw error
        }
        try await rejectInvalidProposal(
            id: id,
            proposal: proposal,
            error: error
        )
    }

    func rejectInvalidProposal(
        id: String,
        proposal: WalletConnectSessionProposal,
        error: WalletConnectSessionApprovalError
    ) async throws(WalletConnectSessionApprovalError) -> Never {
        let result = await rejectProposalAfterApprovalFailure(
            id: id,
            reason: error.proposalRejectionReason,
            context: "proposal approval failed with \(error.logDescription)"
        )
        switch result {
        case .completed,
             .failedTerminal:
            clear(id: proposal.id, pairingTopic: proposal.pairingTopic)
            throw error
        case let .failedRetryable(rejectionError):
            throw .rejectionFailed(rejectionError)
        }
    }

    func rejectProposalAfterApprovalFailure(
        id: String,
        reason: RejectionReason,
        context: String
    ) async -> WalletConnectProposalRejectionResult {
        do {
            try await network.rejectProposal(
                id: id,
                reason: reason
            )
            return .completed
        } catch {
            logProposalRejectionAfterFailure(id: id, context: context, error: error)
            if error.isRetryableDeliveryFailure {
                return .failedRetryable(error)
            }
            return .failedTerminal
        }
    }

    func requiredChains(
        _ proposal: WalletConnectSessionProposal
    ) -> Set<WalletConnectChain> {
        Set(proposal.namespaces.filter(\.isRequired).flatMap(\.chains))
    }

    func optionalChains(
        _ proposal: WalletConnectSessionProposal
    ) -> Set<WalletConnectChain> {
        Set(proposal.namespaces.filter { !$0.isRequired }.flatMap(\.chains))
    }
}

private struct WalletConnectProposalReceiveKey: Hashable {
    let pairingTopic: String
    let proposalId: String
}

struct WalletConnectApprovedProposal: Equatable {
    let proposal: WalletConnectSessionProposal
    let session: WalletConnectSession
    let walletId: String
}

private struct WalletConnectPendingProposal {
    let context: WalletConnectProposalContext
    let source: DappConnectionSource

    var id: String {
        context.id
    }

    var pairingTopic: String {
        context.pairingTopic
    }

    var requiredNamespaces: [String: ProposalNamespace] {
        context.requiredNamespaces
    }

    var optionalNamespaces: [String: ProposalNamespace]? {
        context.optionalNamespaces
    }

    func domain(namespaceBuilder: WalletConnectSessionNamespaceBuilder) -> WalletConnectSessionProposal {
        context.proposal(
            source: source,
            namespaceBuilder: namespaceBuilder
        )
    }
}

private enum WalletConnectProposalRejectionResult {
    case completed
    case failedRetryable(WalletConnectSessionRejectionError)
    case failedTerminal
}

private func logProposalRejectionAfterFailure(
    id: String,
    context: String,
    error: Error
) {
    Log.e(
        "WalletConnect: failed to reject session proposal after \(context)",
        error: error,
        extraInfo: ["proposalId": id]
    )
}

private func proposalLogInfo(_ proposal: WalletConnectSessionProposal) -> [String: String] {
    [
        "proposalId": proposal.id,
    ]
}
