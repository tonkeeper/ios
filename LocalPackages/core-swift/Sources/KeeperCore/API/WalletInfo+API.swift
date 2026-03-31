import Foundation
import TonAPI
import TonSwift

extension WalletInfo {
    init(wallet: TonAPI.Wallet) throws {
        address = try Address.parse(wallet.address)
        isWallet = wallet.isWallet
        balance = wallet.balance
        lastActivity = wallet.lastActivity
        plugins = try wallet.plugins
            .map {
                try WalletInfoPlugin(
                    address: Address.parse($0.address),
                    type: $0.type,
                    status: .init(rawValue: $0.status.rawValue)
                )
            }
    }
}
