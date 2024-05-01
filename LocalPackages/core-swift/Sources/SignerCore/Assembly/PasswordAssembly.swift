import Foundation

public final class PasswordAssembly {
  
  let repositoriesAssembly: RepositoriesAssembly
  let storesAssembly: StoresAssembly
  
  init(repositoriesAssembly: RepositoriesAssembly,
       storesAssembly: StoresAssembly) {
    self.repositoriesAssembly = repositoriesAssembly
    self.storesAssembly = storesAssembly
  }
  
  public func passwordCreateController() -> PasswordCreateController {
    PasswordCreateController(passwordRepository: repositoriesAssembly.passwordRepository())
  }
  
  public func passcodeConfirmationController() -> PasswordConfirmationController {
    PasswordConfirmationController(
      passwordRepository: repositoriesAssembly.passwordRepository()
    )
  }
}
