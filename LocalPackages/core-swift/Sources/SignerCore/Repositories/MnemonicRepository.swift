import Foundation
import CoreComponents

public protocol MnemonicsRepository {
  func getMnemonic(walletKey: WalletKey, 
                   password: String) throws -> CoreComponents.Mnemonic
  func saveMnemonic(_ mnemonic: CoreComponents.Mnemonic,
                    walletKey: WalletKey,
                    password: String) throws
  func checkIfPasswordValid(_ password: String) -> Bool
  func changePassword(oldPassword: String, newPassword: String) throws
}

extension MnemonicsV2Vault: MnemonicsRepository {
  public func getMnemonic(walletKey: WalletKey, 
                          password: String) throws -> Mnemonic {
    try loadMnemonic(
      key: walletKey.publicKey.hexString,
      password: password
    )
  }
  
  public func saveMnemonic(_ mnemonic: Mnemonic, 
                           walletKey: WalletKey,
                           password: String) throws {
    try saveMnemonic(
      mnemonic,
      key: walletKey.publicKey.hexString,
      password: password
    )
  }
  
  public func checkIfPasswordValid(_ password: String) -> Bool {
    do {
      try self.validatePassword(password)
      return true
    } catch {
      return false
    }
  }
}
