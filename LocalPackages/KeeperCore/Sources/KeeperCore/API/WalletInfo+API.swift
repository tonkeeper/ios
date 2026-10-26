import Foundation
import TonAPI
import TonSwift

extension WalletInfo {
    init(wallet: TonAPI.Components.Schemas.Wallet) throws {
        address = try Address.parse(wallet.address)
        isWallet = wallet.isWallet
        signatureDisabled = wallet.signatureDisabled
        balance = wallet.balance
        lastActivity = wallet.lastActivity
        lastLt = wallet.lastLt
        plugins = try wallet.plugins
            .map {
                try WalletInfoPlugin(
                    address: Address.parse($0.address),
                    type: $0._type,
                    status: .init(rawValue: $0.status.rawValue)
                )
            }
    }
}
