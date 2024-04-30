import Foundation
import CoreComponents
import TonSwift

public enum WalletMnemonicRepositoryError: Swift.Error {
  case incorrectWalletIdentity(wallet: Wallet)
  case noMnemonic(wallet: Wallet)
  case other(Swift.Error)
}

public protocol WalletMnemonicRepository {
  func getMnemonic(forWallet wallet: Wallet) throws -> CoreComponents.Mnemonic
  func saveMnemonic(_ mnemonic: CoreComponents.Mnemonic, forWallet wallet: Wallet) throws
}

extension MnemonicVault: WalletMnemonicRepository {
  public func getMnemonic(forWallet wallet: Wallet) throws -> CoreComponents.Mnemonic {
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
                           forWallet wallet: Wallet) throws {
    do {
      let walletKey = try wallet.identity.identifier().string
      try saveValue(mnemonic, for: walletKey)
    } catch is TonSwift.TonError {
      throw WalletMnemonicRepositoryError.incorrectWalletIdentity(wallet: wallet)
    } catch {
      throw WalletMnemonicRepositoryError.other(error)
    }
  }
}
