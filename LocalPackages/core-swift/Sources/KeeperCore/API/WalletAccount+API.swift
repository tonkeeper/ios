import Foundation
import TonSwift
import TonAPI

extension WalletAccount {
  init(accountAddress: Components.Schemas.AccountAddress) throws {
    address = try Address.parse(accountAddress.address)
    name = accountAddress.name
    isScam = accountAddress.is_scam
    isWallet = accountAddress.is_wallet
  }
}

