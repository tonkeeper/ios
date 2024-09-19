import TKUIKit
import TKCoordinator
import TKCore
import KeeperCore

struct ReceiveModule {
  private let dependencies: Dependencies
  init(dependencies: Dependencies) {
    self.dependencies = dependencies
  }
  
  func receiveModule(token: Token,
                     wallet: Wallet) -> MVVMModule<ReceiveViewController, ReceiveModuleOutput, Void> {
    return ReceiveAssembly.module(
      token: token,
      wallet: wallet,
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
