import Foundation
import CoreComponents
import TonSwift

public enum WalletKeyMnemonicRepositoryError: Swift.Error {
  case incorrectWalletKey(walletKey: WalletKey)
  case noMnemonic(walletKey: WalletKey)
  case other(Swift.Error)
}

public protocol WalletKeyMnemonicRepository {
  func getMnemonic(forWalletKey walletKey: WalletKey) throws -> CoreComponents.Mnemonic
  func saveMnemonic(_ mnemonic: CoreComponents.Mnemonic, forWalletKey walletKey: WalletKey) throws
}

extension MnemonicVault: WalletKeyMnemonicRepository {
  public func getMnemonic(forWalletKey walletKey: WalletKey) throws -> CoreComponents.Mnemonic {
    do {
      return try loadValue(key: walletKey.publicKey.hexString)
    } catch is TonSwift.TonError {
      throw WalletKeyMnemonicRepositoryError.incorrectWalletKey(walletKey: walletKey)
    } catch KeychainVaultError.noItemFound {
      throw WalletKeyMnemonicRepositoryError.noMnemonic(walletKey: walletKey)
    } catch {
      throw WalletKeyMnemonicRepositoryError.other(error)
    }
  }
  
  public func saveMnemonic(_ mnemonic: CoreComponents.Mnemonic,
                           forWalletKey walletKey: WalletKey) throws {
    do {
      try saveValue(mnemonic, for: walletKey.publicKey.hexString)
    } catch is TonSwift.TonError {
      throw WalletKeyMnemonicRepositoryError.incorrectWalletKey(walletKey: walletKey)
    } catch {
      throw WalletKeyMnemonicRepositoryError.other(error)
    }
  }
}
