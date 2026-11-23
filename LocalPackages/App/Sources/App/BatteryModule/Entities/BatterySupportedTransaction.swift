import Foundation
import KeeperCore
import TKLocalize

enum BatterySupportedTransaction: String, CaseIterable {
    case swap
    case jetton
    case nft
    case trc20

    var name: String {
        switch self {
        case .swap:
            TKLocales.Battery.Settings.Items.Swaps.title
        case .jetton:
            TKLocales.Battery.Settings.Items.Token.title
        case .nft:
            TKLocales.Battery.Settings.Items.Nft.title
        case .trc20:
            TKLocales.Battery.Settings.Items.Trc20.title
        }
    }
}

extension Wallet {
    var supportedBatteryTransactions: [BatterySupportedTransaction] {
        // A Ledger has the battery on TRON alone, where its swaps and USDT go.
        guard kind != .ledger else {
            return multichainWalletState?.address(for: .tron) == nil ? [] : [.swap, .trc20]
        }
        var transactions: [BatterySupportedTransaction] = [.swap, .jetton, .nft]
        if tron != nil || multichainWalletState?.address(for: .tron) != nil {
            transactions.append(.trc20)
        }
        return transactions
    }
}

struct BatteryTransactionNetwork: Equatable {
    let chain: MultichainChain
    let transactions: [BatterySupportedTransaction]
}

extension Wallet {
    /// What the battery pays for on each network: TON, TRON and the relayed EVM chains and Solana in `relayedChains`.
    func batteryTransactionNetworks(relayedChains: [MultichainChain]) -> [BatteryTransactionNetwork] {
        let supported = supportedBatteryTransactions
        var networks: [BatteryTransactionNetwork] = []
        if supported.contains(.jetton) {
            networks.append(BatteryTransactionNetwork(chain: .ton, transactions: [.swap, .jetton, .nft]))
        }
        if supported.contains(.trc20) {
            networks.append(BatteryTransactionNetwork(chain: .tron, transactions: [.swap, .trc20]))
        }
        networks += relayedChains.map { BatteryTransactionNetwork(chain: $0, transactions: [.swap, .jetton]) }
        return networks
    }
}
