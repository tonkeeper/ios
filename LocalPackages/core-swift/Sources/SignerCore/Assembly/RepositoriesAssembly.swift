import Foundation
import CoreComponents

public final class RepositoriesAssembly {
  
  private let coreAssembly: CoreAssembly
  
  init(coreAssembly: CoreAssembly) {
    self.coreAssembly = coreAssembly
  }
  
  public func mnemonicRepository() -> WalletKeyMnemonicRepository {
    coreAssembly.mnemonicVault()
  }
  
  public func signerInfoRepository() -> SignerInfoRepository {
    coreAssembly.fileSystemVault()
  }
  
  public func passwordRepository() -> PasswordRepository {
    PasswordRepositoryImplementation(passwordVault: coreAssembly.passwordVault())
  }
}
