import Foundation
import KeeperCore

/// The networks the battery pays fees on: TON and TRON, and the EVM chains and Solana its relayer serves.
struct BatteryNetworks {
    /// Until the relayer's config is read, the battery is described by TON and TRON alone.
    static let tonAndTron = BatteryNetworks(relayedChains: [])

    let relayedChains: [MultichainChain]

    /// The relayed chains the relayer can take `wallet`'s fees on. As in the transfer and swap
    /// engines, that takes a regular mainnet multichain wallet, and only on chains it has an address on.
    init(relayedEVMChains: Set<MultichainChain>, wallet: Wallet) {
        guard wallet.kind == .regular,
              wallet.network.isMainnet,
              let state = wallet.multichainWalletState
        else {
            self.init(relayedChains: [])
            return
        }
        self.init(relayedChains: relayedEVMChains.filter { state.address(for: $0) != nil })
    }

    private init(relayedChains: Set<MultichainChain>) {
        self.relayedChains = MultichainChain.orderedByDisplayOrder(Array(relayedChains))
    }

    var includesEVM: Bool {
        relayedChains.contains(where: \.isEVM)
    }

    var includesSolana: Bool {
        relayedChains.contains(.sol)
    }
}
