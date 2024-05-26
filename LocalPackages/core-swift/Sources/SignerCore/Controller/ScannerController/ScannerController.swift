import Foundation
import TonSwift

public final class ScannerController {
  
  public enum ScannerControllerError: Swift.Error {
    case invalidBoc(String)
  }

  private let deeplinkParser = DefaultDeeplinkParser(
    parsers: [TonsignDeeplinkParser()]
  )
  
  public func handleScannedQRCode(_ qrCodeString: String) throws -> Deeplink {
    do {
      let deeplink = try deeplinkParser.parse(string: qrCodeString)
      switch deeplink {
      case .tonsign(let tonsignDeeplink):
        switch tonsignDeeplink {
        case .plain:
          return deeplink
        case .sign(let tonSignModel):
          try validateBodyBoc(tonSignModel.body)
          return deeplink
        }
      }
    } catch {
      throw error
    }
  }
  
  public func isQRCodeStartString(_ string: String) -> Bool {
    string.hasPrefix(DeeplinkScheme.tonsign.rawValue)
  }
}

private extension ScannerController {
  func validateBodyBoc(_ boc: Data) throws {
    do {
      _ = try Cell.cellFromBoc(src: boc)
    } catch {
      throw ScannerControllerError.invalidBoc(boc.hexString())
    }
  }
}
