import Foundation

public final class RecoveryPhraseController {
  
  private let wallet: Wallet
  private let mnemonicRepository: WalletMnemonicRepository
  
  init(wallet: Wallet, 
       mnemonicRepository: WalletMnemonicRepository) {
    self.wallet = wallet
    self.mnemonicRepository = mnemonicRepository
  }
  
  public func getRecoveryPhrase() -> [String] {
    do {
      let phrase = try mnemonicRepository.getMnemonic(forWallet: wallet)
      return phrase.mnemonicWords
    } catch {
      return []
    }
  }
}
