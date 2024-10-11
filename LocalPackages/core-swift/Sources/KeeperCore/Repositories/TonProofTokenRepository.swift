import Foundation
import CoreComponents

final class TonProofTokenRepository {
  private let keychainVault: KeychainVault
  
  init(keychainVault: KeychainVault) {
    self.keychainVault = keychainVault
  }
  
  func getTonProofToken(wallet: Wallet) throws -> String {
    try keychainVault.read(getQuery(key: wallet.address.toRaw()))
  }
  
  func saveTonProofToken(wallet: Wallet, token: String) throws {
    try keychainVault.save(token, item: getQuery(key: wallet.address.toRaw()))
  }
  
  private func getQuery(key: String) -> KeychainQueryable {
    KeychainGenericPasswordItem(service: .key,
                                account: key,
                                accessGroup: nil,
                                accessible: .whenUnlockedThisDeviceOnly)
  }
}

private extension String {
  static let key: String = "TonProof"
}
