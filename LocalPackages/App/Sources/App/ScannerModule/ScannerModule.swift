import TKUIKit
import TKCoordinator
import TKCore
import TKLocalize
import KeeperCore

struct ScannerModule {
  private let dependencies: Dependencies
  init(dependencies: Dependencies) {
    self.dependencies = dependencies
  }
  
  func createScannerModule(configurator: ScannerControllerConfigurator,
                           uiConfiguration: ScannerUIConfiguration) -> MVVMModule<ScannerViewController, ScannerViewModuleOutput, Void> {
    ScannerAssembly.module(
      scannerController: dependencies.scannerAssembly.scannerController(configurator: configurator),
      urlOpener: dependencies.coreAssembly.urlOpener(),
      uiConfiguration: uiConfiguration
    )
  }
}

extension ScannerModule {
  struct Dependencies {
    let coreAssembly: TKCore.CoreAssembly
    let scannerAssembly: KeeperCore.ScannerAssembly
    
    public init(coreAssembly: TKCore.CoreAssembly,
                scannerAssembly: KeeperCore.ScannerAssembly) {
      self.coreAssembly = coreAssembly
      self.scannerAssembly = scannerAssembly
    }
  }
}
