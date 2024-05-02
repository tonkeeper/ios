import Foundation

public final class ScannerAssembly {
  public func scannerController(configurator: ScannerControllerConfigurator) -> ScannerController {
    ScannerController(
      configurator: configurator
    )
  }
  
  public func signerScanController() -> SignerScanController {
    SignerScanController(deeplinkGenerator: DeeplinkGenerator())
  }
}
