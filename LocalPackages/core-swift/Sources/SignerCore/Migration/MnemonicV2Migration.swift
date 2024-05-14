import Foundation

public struct MnemonicV2Migration {
  
  private let signerInfoRepository: SignerInfoRepository
  private let oldMnemonicRepository: WalletKeyMnemonicRepository
  private let mnemonicsRepository: MnemonicsRepository
  private let passwordRepository: PasswordRepository
  
  public init(signerInfoRepository: SignerInfoRepository, 
       oldMnemonicRepository: WalletKeyMnemonicRepository,
       mnemonicsRepository: MnemonicsRepository,
       passwordRepository: PasswordRepository) {
    self.signerInfoRepository = signerInfoRepository
    self.oldMnemonicRepository = oldMnemonicRepository
    self.mnemonicsRepository = mnemonicsRepository
    self.passwordRepository = passwordRepository
  }
  
  public func migrateIfNeeded() {
    guard let signerInfo = try? signerInfoRepository.getSignerInfo(),
          let password = try? passwordRepository.getPassword() else { return }
    signerInfo.walletKeys.forEach { walletKey in
      guard let mnemonic = try? oldMnemonicRepository.getMnemonic(forWalletKey: walletKey) else { return }
      try? mnemonicsRepository.saveMnemonic(mnemonic, walletKey: walletKey, password: password.hashed)
      try? oldMnemonicRepository.deleteMnemonic(forWalletKey: walletKey)
    }
    try? passwordRepository.deletePassword()
  }
}
