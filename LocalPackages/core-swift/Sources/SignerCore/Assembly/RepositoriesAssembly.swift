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
    coreAssembly.mnemonicsV3Vault { [weak self] in
      guard let self else { return "" }
      return self.settingsRepository().seed
    }
  }
  
  public func oldMnemonicRepository() -> MnemonicsRepository {
    coreAssembly.mnemonicsV2Vault { [weak self] in
      guard let self else { return "" }
      return self.settingsRepository().seed
    }
  }
  
  public func signerInfoRepository() -> SignerInfoRepository {
    coreAssembly.fileSystemVault()
  }
  
  public func passwordRepository() -> PasswordRepository {
    PasswordRepositoryImplementation(passwordVault: coreAssembly.passwordVault())
  }
  
  public func mnemonicV2ToV3Migration() -> MnemonicV2ToV3Migration {
    let seedProvider = { [weak self] in
      guard let self else { return "" }
      return self.settingsRepository().seed
    }
    return MnemonicV2ToV3Migration(
      migration: CoreComponents.MnemonicV2ToV3Migration(
        v2Vault: coreAssembly.mnemonicsV2Vault(seedProvider: seedProvider),
        v3Vault: coreAssembly.mnemonicsV3Vault(seedProvider: seedProvider)
      )
    )
  }
}
