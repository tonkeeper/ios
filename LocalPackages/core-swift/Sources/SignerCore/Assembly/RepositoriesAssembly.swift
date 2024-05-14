import Foundation
import CoreComponents

public final class RepositoriesAssembly {
  
  private let coreAssembly: CoreAssembly
  
  init(coreAssembly: CoreAssembly) {
    self.coreAssembly = coreAssembly
  }
  
  public func settingsRepository() -> SettingsRepository {
    SettingsRepository(settingsVault: coreAssembly.settingsVault())
  }
  
  public func mnemonicsRepository() -> MnemonicsRepository {
    coreAssembly.mnemonicsV2Vault { [weak self] in
      guard let self else { return "" }
      return self.settingsRepository().seed
    }
  }
  public func oldMnemonicRepository() -> WalletKeyMnemonicRepository {
    coreAssembly.mnemonicVault()
  }
  
  public func signerInfoRepository() -> SignerInfoRepository {
    coreAssembly.fileSystemVault()
  }
  
  public func passwordRepository() -> PasswordRepository {
    PasswordRepositoryImplementation(passwordVault: coreAssembly.passwordVault())
  }
}
