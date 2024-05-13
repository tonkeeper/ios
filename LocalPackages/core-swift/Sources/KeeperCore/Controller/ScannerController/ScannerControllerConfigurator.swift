import Foundation

public protocol ScannerControllerConfigurator {
  func handleQRCode(_ qrCode: String) throws -> Deeplink
}

public struct DefaultScannerControllerConfigurator: ScannerControllerConfigurator {
  
  private let deeplinkParser = DefaultDeeplinkParser(
    parsers: [TonDeeplinkParser(),
              TonConnectDeeplinkParser(),
              TonkeeperDeeplinkParser()]
  )
  
  public init() {}
  
  public func handleQRCode(_ qrCode: String) throws -> Deeplink {
    return try deeplinkParser.parse(string: qrCode)
  }
}
