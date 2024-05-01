import Foundation

public final class RecoveryPhraseController {
  private let key: WalletKey
  private let mnemonicRepository: WalletKeyMnemonicRepository
  
  init(key: WalletKey, mnemonicRepository: WalletKeyMnemonicRepository) {
    self.key = key
    self.mnemonicRepository = mnemonicRepository
  }
  
  public func getRecoveryPhrase() -> [String] {
    do {
      let phrase = try mnemonicRepository.getMnemonic(forWalletKey: key)
      return phrase.mnemonicWords
    } catch {
      return []
    }
  }
}
