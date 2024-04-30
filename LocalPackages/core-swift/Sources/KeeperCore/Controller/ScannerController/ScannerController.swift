import Foundation

public final class ScannerController {
  
  private let deeplinkParser: DeeplinkParser
  
  init(deeplinkParser: DeeplinkParser) {
    self.deeplinkParser = deeplinkParser
  }
  
  public func handleScannedQRCode(_ qrCodeString: String) throws -> Deeplink {
    return try deeplinkParser.parse(string: qrCodeString)
  }
}
