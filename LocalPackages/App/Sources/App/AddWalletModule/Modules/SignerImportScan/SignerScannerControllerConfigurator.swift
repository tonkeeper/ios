import Foundation
import KeeperCore
import URKit

struct SignerScannerControllerConfigurator: ScannerControllerConfigurator {
  
  enum Error: Swift.Error {
    case unsupportedDeeplink(deeplink: Deeplink)
  }
  
  private let deeplinkParser = DeeplinkParser()
  private let urDecoder = URDecoder()
  
  init() {}
  
  func handleQRCode(_ qrCode: String) throws -> Deeplink {
    let deeplink = try deeplinkParser.parse(string: qrCode)
    
    guard case let .externalSign(externalSign) = deeplink,
          case let .link(publicKey, name) = externalSign else {
      throw Error.unsupportedDeeplink(deeplink: deeplink)
    }
    return deeplink
  }
  
  public func handleQRCodeUR(_ qrCode: String) throws -> UR {
    urDecoder.receivePart(qrCode)

    guard let result = urDecoder.result else {
      throw URError.noResult
    }
    return try result.get()
  }
}
