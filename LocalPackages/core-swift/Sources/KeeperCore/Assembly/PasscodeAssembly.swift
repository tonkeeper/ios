import Foundation

public final class PasscodeAssembly {
  
  public let repositoriesAssembly: RepositoriesAssembly
  public let storesAssembly: StoresAssembly
  
  init(repositoriesAssembly: RepositoriesAssembly,
       storesAssembly: StoresAssembly) {
    self.repositoriesAssembly = repositoriesAssembly
    self.storesAssembly = storesAssembly
  }
  
  public func passcodeCreateController() -> PasscodeCreateController {
    PasscodeCreateController(passcodeRepository: repositoriesAssembly.passcodeRepository())
  }
  
  public func passcodeConfirmationController() -> PasscodeConfirmationController {
    PasscodeConfirmationController(
      passcodeRepository: repositoriesAssembly.passcodeRepository(),
      securityStore: storesAssembly.securityStore
    )
  }
}
