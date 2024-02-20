import TKUIKit
import TKCoordinator
import TKCore
import KeeperCore

struct ScannerModule {
  private let dependencies: Dependencies
  init(dependencies: Dependencies) {
    self.dependencies = dependencies
  }
  
  func createScannerModule() -> MVVMModule<ScannerViewController, ScannerViewModuleOutput, Void> {
    ScannerAssembly.module(
      scannerController: dependencies.keeperCoreMainAssembly.scannerController(),
      urlOpener: dependencies.coreAssembly.urlOpener()
    )
  }
}

extension ScannerModule {
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
