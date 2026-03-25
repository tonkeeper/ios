import Foundation
import TonAPI
import TonSwift

extension WalletAccount {
    init(accountAddress: TonAPI.AccountAddress) throws {
        address = try Address.parse(accountAddress.address)
        name = accountAddress.name
        isScam = accountAddress.isScam
        isWallet = accountAddress.isWallet
    }
}
