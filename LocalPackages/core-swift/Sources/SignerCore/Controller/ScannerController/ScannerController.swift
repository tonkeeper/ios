import Foundation

public final class ScannerController {

  private let deeplinkParser = DefaultDeeplinkParser(
    parsers: [TonsignDeeplinkParser()]
  )
  
  public func handleScannedQRCode(_ qrCodeString: String) throws -> Deeplink {
    try deeplinkParser.parse(string: qrCodeString)
  }
}
