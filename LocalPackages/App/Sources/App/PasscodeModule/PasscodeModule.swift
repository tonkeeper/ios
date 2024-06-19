import TKUIKit
import TKCoordinator
import TKCore
import KeeperCore

public struct PasscodeModule {
  private let dependencies: Dependencies
  init(dependencies: Dependencies) {
    self.dependencies = dependencies
  }
}

extension PasscodeModule {
  struct Dependencies {
    let passcodeAssembly: KeeperCore.PasscodeAssembly
    
    init(passcodeAssembly: KeeperCore.PasscodeAssembly) {
      self.passcodeAssembly = passcodeAssembly
    }
  }
}
