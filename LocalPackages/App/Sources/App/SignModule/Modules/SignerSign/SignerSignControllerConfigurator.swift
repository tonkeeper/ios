import Foundation
import KeeperCore

struct SignerSignControllerConfigurator: ScannerControllerConfigurator {
  
  enum Error: Swift.Error {
    case unsupportedDeeplink(deeplink: Deeplink)
  }
  
  private let deeplinkParser = DefaultDeeplinkParser(
    parsers: [TonkeeperDeeplinkParser()]
  )
  
  init() {}
  
  func handleQRCode(_ qrCode: String) throws -> Deeplink {
    let deeplink = try deeplinkParser.parse(string: qrCode)
    
    guard case let .tonkeeper(tonkeeperDeeplink) = deeplink,
          case .publish(_) = tonkeeperDeeplink else {
      throw Error.unsupportedDeeplink(deeplink: deeplink)
    }
    return deeplink
  }
}
