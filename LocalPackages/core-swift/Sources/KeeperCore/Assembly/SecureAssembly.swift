import Foundation
import CoreComponents

public struct SecureAssembly {
  
  private let coreAssembly: CoreAssembly
  
  init(coreAssembly: CoreAssembly) {
    self.coreAssembly = coreAssembly
  }
  
  public func mnemonicsRepository() -> MnemonicsRepository {
    coreAssembly.mnemonicsVault()
  }
  
  public func rnMnemonicsRepository() -> MnemonicsRepository {
    coreAssembly.rnMnemonicsVault()
  }
}
