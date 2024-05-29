import Foundation

public final class ScannerController {
  
  private let configurator: ScannerControllerConfigurator
  
  init(configurator: ScannerControllerConfigurator) {
    self.configurator = configurator
  }
  
  public func handleScannedQRCode(_ qrCodeString: String) throws -> Deeplink {
    return try configurator.handleQRCode(qrCodeString)
  }
}
