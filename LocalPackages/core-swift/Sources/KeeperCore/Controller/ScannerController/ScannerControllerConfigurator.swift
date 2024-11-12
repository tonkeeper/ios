import Foundation
import URKit
import TonSwift

public protocol ScannerControllerConfigurator {
  func handleQRCode(_ qrCode: String) throws -> Deeplink
  func handleQRCodeUR(_ qrCode: String) throws -> UR
}

public enum URError: Error {
    case noResult
    
    public var errorDescription: String? {
        switch self {
        case .noResult:
            return "URError: no result"
        }
    }
}


public struct DefaultScannerControllerConfigurator: ScannerControllerConfigurator {
  
  private let deeplinkParser = DeeplinkParser()
  private let urDecoder = URDecoder()
  
  public init() {}
  
  public func handleQRCode(_ qrCode: String) throws -> Deeplink {
    do {
      _ = try Address.parse(qrCode)
      // QR code is a valid address, so we should resolve it as transfer with recipient
      let tonTransfer = Deeplink.transfer(.init(recipient: qrCode, amount: nil, comment: nil, jettonAddress: nil, expirationTimestamp: nil))
      return tonTransfer
    } catch {}
    return try deeplinkParser.parse(string: qrCode)
  }
  
  public func handleQRCodeUR(_ qrCode: String) throws -> UR {
    urDecoder.receivePart(qrCode)

    guard let result = urDecoder.result else {
      throw URError.noResult
    }
    return try result.get()
  }
}
