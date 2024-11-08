import Foundation
import TKKeychain

final class TonProofTokenRepository {
  private let keychainVault: TKKeychainVault
  
  init(keychainVault: TKKeychainVault) {
    self.keychainVault = keychainVault
  }
  
  func getTonProofToken(wallet: Wallet) throws -> String {
    try keychainVault.get(query: createKeychainQuery(key: wallet.address.toRaw() + "2"))
  }
  
  func saveTonProofToken(wallet: Wallet, token: String) throws {
    try keychainVault.set(token, query: createKeychainQuery(key: wallet.address.toRaw() + "2"))
  }
  
  private func createKeychainQuery(key: String) -> TKKeychainQuery {
    TKKeychainQuery(
      item: .genericPassword(service: .key, account: key),
      accessGroup: nil,
      biometry: .none,
      accessible: .whenUnlockedThisDeviceOnly
    )
  }
}

private extension String {
  static let key: String = "TonProof"
}
