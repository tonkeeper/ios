import Foundation
import URKit

public final class ScannerController {
  
  private let configurator: ScannerControllerConfigurator
  
  init(configurator: ScannerControllerConfigurator) {
    self.configurator = configurator
  }
  
  public func handleScannedQRCode(_ qrCodeString: String) throws -> Deeplink {
    return try configurator.handleQRCode(qrCodeString)
  }
  
  public func handleScannedQRCodeUR(_ qrCodeString: String) throws -> UR {
    return try configurator.handleQRCodeUR(qrCodeString)
  }
}
