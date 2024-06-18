import Foundation
import CoreComponents
import TonSwift

public enum WalletMnemonicRepositoryError: Swift.Error {
  case incorrectWalletIdentity(wallet: Version11V1.Wallet)
  case noMnemonic(wallet: Version11V1.Wallet)
  case other(Swift.Error)
}

public protocol WalletMnemonicRepository {
  func getMnemonic(forWallet wallet: Version11V1.Wallet) throws -> CoreComponents.Mnemonic
  func saveMnemonic(_ mnemonic: CoreComponents.Mnemonic, forWallet wallet: Version11V1.Wallet) throws
  func deleteMnemonic(for wallet: Version11V1.Wallet) throws
  func deleteAll() throws
}

extension MnemonicVault: WalletMnemonicRepository {
  public func getMnemonic(forWallet wallet: Version11V1.Wallet) throws -> CoreComponents.Mnemonic {
    do {
      let walletKey = try wallet.identity.identifier().string
      return try loadValue(key: walletKey)
    } catch is TonSwift.TonError {
      throw WalletMnemonicRepositoryError.incorrectWalletIdentity(wallet: wallet)
    } catch KeychainVaultError.noItemFound {
      throw WalletMnemonicRepositoryError.noMnemonic(wallet: wallet)
    } catch {
      throw WalletMnemonicRepositoryError.other(error)
    }
  }
  
  public func saveMnemonic(_ mnemonic: CoreComponents.Mnemonic,
                           forWallet wallet: Version11V1.Wallet) throws {
    do {
      let walletKey = try wallet.identity.identifier().string
      try saveValue(mnemonic, for: walletKey)
    } catch is TonSwift.TonError {
      throw WalletMnemonicRepositoryError.incorrectWalletIdentity(wallet: wallet)
    } catch {
      throw WalletMnemonicRepositoryError.other(error)
    }
  }
  
  public func deleteMnemonic(for wallet: Version11V1.Wallet) throws {
    let walletKey = try wallet.identity.identifier().string
    try deleteValue(for: walletKey)
  }
  
  public func deleteAll() throws {
    try deleteAllValues()
  }
}
