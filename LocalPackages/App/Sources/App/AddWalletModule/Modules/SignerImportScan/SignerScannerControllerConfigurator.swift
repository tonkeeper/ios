import Foundation
import KeeperCore

struct SignerScannerControllerConfigurator: ScannerControllerConfigurator {
  
  enum Error: Swift.Error {
    case unsupportedDeeplink(deeplink: Deeplink)
  }
  
  private let deeplinkParser = DeeplinkParser()
  
  init() {}
  
  func handleQRCode(_ qrCode: String) throws -> Deeplink {
    let deeplink = try deeplinkParser.parse(string: qrCode)
    
    guard case let .externalSign(externalSign) = deeplink,
          case let .link(publicKey, name) = externalSign else {
      throw Error.unsupportedDeeplink(deeplink: deeplink)
    }
    return deeplink
  }
}
