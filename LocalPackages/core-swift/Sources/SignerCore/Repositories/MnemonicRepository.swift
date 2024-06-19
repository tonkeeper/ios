import Foundation
import CoreComponents

public protocol MnemonicsRepository {
  func getMnemonic(walletKey: WalletKey, 
                   password: String) async throws -> CoreComponents.Mnemonic
  func saveMnemonic(_ mnemonic: CoreComponents.Mnemonic,
                    walletKey: WalletKey,
                    password: String) async throws
  func deleteMnemonic(walletKey: WalletKey,
                      password: String) async throws
  func checkIfPasswordValid(_ password: String) async -> Bool
  func changePassword(oldPassword: String, newPassword: String) async throws
  func deleteAll() async throws
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
  
  public func deleteMnemonic(walletKey: WalletKey, password: String) throws {
    try deleteMnemonic(
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

extension MnemonicsV3Vault: MnemonicsRepository {
  public func getMnemonic(walletKey: WalletKey, password: String) async throws -> CoreComponents.Mnemonic {
    try await getMnemonic(identifier: walletKey.publicKey.hexString, password: password)
  }
  
  public func saveMnemonic(_ mnemonic: CoreComponents.Mnemonic, walletKey: WalletKey, password: String) async throws {
    try await addMnemonic(mnemonic, identifier: walletKey.publicKey.hexString, password: password)
  }
  
  public func deleteMnemonic(walletKey: WalletKey, password: String) async throws {
    try await deleteMnemonic(identifier: walletKey.publicKey.hexString, password: password)
  }
  
  public func checkIfPasswordValid(_ password: String) async -> Bool {
    do {
      try await validatePassword(password)
      return true
    } catch {
      return false
    }
  }
}

