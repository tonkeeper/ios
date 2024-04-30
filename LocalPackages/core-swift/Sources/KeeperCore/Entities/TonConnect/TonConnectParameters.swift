import Foundation

public struct TonConnectParameters {
  enum Version: String {
    case v2 = "2"
  }
  
  let version: Version
  let clientId: String
  let requestPayload: TonConnectRequestPayload
}
