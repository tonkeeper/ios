import Foundation
import TonAPI
import TonSwift

extension WalletAccount {
    init(accountAddress: TonAPI.Components.Schemas.AccountAddress) throws {
        address = try Address.parse(accountAddress.address)
        name = accountAddress.name
        isScam = accountAddress.isScam
        isWallet = accountAddress.isWallet
    }
}
