import TKUIKit
import TKCoordinator
import TKCore
import KeeperCore

struct ReceiveModule {
  private let dependencies: Dependencies
  init(dependencies: Dependencies) {
    self.dependencies = dependencies
  }
  
  func receiveModule(token: Token) -> MVVMModule<ReceiveViewController, ReceiveModuleOutput, Void> {
    let receiveController = dependencies.keeperCoreMainAssembly.receiveController(token: token)
    return ReceiveAssembly.module(
      receiveController: receiveController,
      qrCodeGenerator: QRCodeGeneratorImplementation()
    )
  }
}

extension ReceiveModule {
  struct Dependencies {
    let coreAssembly: TKCore.CoreAssembly
    let keeperCoreMainAssembly: KeeperCore.MainAssembly
    
    public init(coreAssembly: TKCore.CoreAssembly,
                keeperCoreMainAssembly: KeeperCore.MainAssembly) {
      self.coreAssembly = coreAssembly
      self.keeperCoreMainAssembly = keeperCoreMainAssembly
    }
  }
}
