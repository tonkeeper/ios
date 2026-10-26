import Foundation
import KeeperCore
import TKLocalize

/// The networks the battery pays fees on: TON and TRON, and the EVM chains its relayer serves.
struct BatteryNetworks {
    /// Until the relayer's config is read, the battery is described by TON and TRON alone.
    static let tonAndTron = BatteryNetworks(evmChains: [])

    let evmChains: [MultichainChain]

    /// The relayed chains the relayer can take `wallet`'s fees on. As in the transfer and swap
    /// engines, that takes a regular mainnet multichain wallet, and only on chains it has an address on.
    init(relayedEVMChains: Set<MultichainChain>, wallet: Wallet) {
        guard wallet.kind == .regular,
              wallet.network.isMainnet,
              let state = wallet.multichainWalletState
        else {
            self.init(evmChains: [])
            return
        }
        self.init(evmChains: relayedEVMChains.filter { state.address(for: $0) != nil })
    }

    private init(evmChains: Set<MultichainChain>) {
        self.evmChains = MultichainChain.orderedByDisplayOrder(Array(evmChains))
    }

    var includesEVM: Bool {
        !evmChains.isEmpty
    }

    /// "Works on TON, TRON, Ethereum and Base"; nil while no EVM chain is relayed.
    var caption: String? {
        guard includesEVM else {
            return nil
        }
        let names = ([.ton, .tron] + evmChains).map(\.shortDisplayTitle)
        let formatter = ListFormatter()
        formatter.locale = AmountFormatter.Configuration.defaultLocale
        return TKLocales.Battery.Settings.networks(formatter.string(from: names) ?? names.joined(separator: ", "))
    }
}
