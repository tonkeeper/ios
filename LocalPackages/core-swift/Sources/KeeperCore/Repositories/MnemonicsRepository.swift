import Foundation
import CoreComponents

public protocol MnemonicsRepository {
  func hasMnemonics() -> Bool
  func getMnemonic(wallet: Wallet,
                   password: String) async throws -> CoreComponents.Mnemonic
  func saveMnemonic(_ mnemonic: CoreComponents.Mnemonic,
                    wallet: Wallet,
                    password: String) async throws
  func saveMnemonic(_ mnemonic: CoreComponents.Mnemonic,
                     wallets: [Wallet],
                     password: String) async throws
  func deleteMnemonic(wallet: Wallet,
                      password: String) async throws
  func checkIfPasswordValid(_ password: String) async -> Bool
  func changePassword(oldPassword: String, newPassword: String) async throws
  func deleteAll() async throws
  
  func savePassword(_ password: String) throws
  func getPassword() throws -> String
  func deletePassword() throws
  func importMnemonics(_ mnemonics: Mnemonics, password: String) async throws
}

extension MnemonicsV3Vault: MnemonicsRepository {
  public func getMnemonic(wallet: Wallet, password: String) async throws -> CoreComponents.Mnemonic {
    try await getMnemonic(identifier: wallet.id, password: password)
  }
  
  public func saveMnemonic(_ mnemonic: CoreComponents.Mnemonic, wallet: Wallet, password: String) async throws {
    try await addMnemonic(mnemonic, identifier: wallet.id, password: password)
  }
  
  public func saveMnemonic(_ mnemonic: CoreComponents.Mnemonic, wallets: [Wallet], password: String) async throws {
    let vaultMnemonics = Dictionary(uniqueKeysWithValues: wallets.map { ($0.id, mnemonic) })
    try await importMnemonics(vaultMnemonics, password: password)
  }
  
  public func deleteMnemonic(wallet: Wallet, password: String) async throws {
    try await deleteMnemonic(identifier: wallet.id, password: password)
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

