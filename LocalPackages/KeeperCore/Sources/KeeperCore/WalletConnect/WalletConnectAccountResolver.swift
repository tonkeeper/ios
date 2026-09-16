import Foundation
import ReownWalletKit

struct WalletConnectAccountResolver {
    func accounts(
        wallet: Wallet,
        requiredChains: Set<WalletConnectChain>,
        optionalChains: Set<WalletConnectChain>
    ) throws(WalletConnectSessionApprovalError) -> [WalletConnectAccount] {
        guard case let .multichain(state) = wallet.multichain,
              !state.addresses.isEmpty
        else {
            throw .missingMultichainAddresses(walletId: wallet.id)
        }

        let accounts = WalletConnectChain.allCases.compactMap { chain -> WalletConnectAccount? in
            guard let address = wallet.walletConnectAddress(for: chain) else {
                return nil
            }
            return WalletConnectAccount(chain: chain, address: address)
        }

        let availableChains = Set(accounts.map(\.chain))
        let requestedChains = requiredChains.union(optionalChains)
        let approvedChains = requestedChains.isEmpty
            ? availableChains
            : requestedChains.intersection(availableChains)

        let missingRequiredChains = requiredChains.subtracting(availableChains)
        if !missingRequiredChains.isEmpty {
            throw .unsupportedRequiredChains(missingRequiredChains.map(\.caip2).sorted())
        }

        return accounts.filter { approvedChains.contains($0.chain) }
    }
}

extension WalletConnectSessionApprovalError {
    var proposalRejectionReason: RejectionReason {
        switch self {
        case .unsupportedRequiredChains:
            return .unsupportedChains
        case .missingMultichainAddresses,
             .invalidAccount,
             .unsupportedWalletKind:
            return .unsupportedAccounts
        case .unsupportedRequiredMethods:
            return .unsupportedMethods
        case .missingProposal,
             .rejectionFailed,
             .storage,
             .sdk:
            return .userRejected
        }
    }
}
