import Foundation
import URKit

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
