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
        var transactions: [BatterySupportedTransaction] = [.swap, .jetton, .nft]
        if isTronTurnOn {
            transactions.append(.trc20)
        }
        return transactions
    }
}
