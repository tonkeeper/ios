import Foundation

public struct TonConnectParameters: Equatable {
  public enum Version: String {
    case v2 = "2"
  }
  
  public let version: Version
  public let clientId: String
  public let requestPayload: TonConnectRequestPayload
  public let returnStrategy: String?
  
  public init(version: Version, clientId: String, requestPayload: TonConnectRequestPayload, returnStrategy: String? = nil) {
    self.version = version
    self.clientId = clientId
    self.requestPayload = requestPayload
    self.returnStrategy = returnStrategy
  }
}
