import Foundation
import TonSwift

enum DeeplinkParserError: Swift.Error {
  case unsupportedDeeplink(string: String?)
  case incorrectPublicKey(String)
}

public protocol DeeplinkParser {
  func parse(string: String?) throws -> Deeplink
}

public struct DefaultDeeplinkParser: DeeplinkParser {
  
  private let parsers: [DeeplinkParser]
  
  public init(parsers: [DeeplinkParser]) {
    self.parsers = parsers
  }
  
  public func parse(string: String?) throws -> Deeplink {
    guard let string else { throw DeeplinkParserError.unsupportedDeeplink(string: string) }
    let deeplink = parsers
        .compactMap { handler -> Deeplink? in try? handler.parse(string: string) }
        .first
    guard let deeplink = deeplink else { throw DeeplinkParserError.unsupportedDeeplink(string: string) }
    return deeplink
  }
}

public struct TonsignDeeplinkParser: DeeplinkParser {
  public func parse(string: String?) throws -> Deeplink {
    guard let string else { throw DeeplinkParserError.unsupportedDeeplink(string: string) }
    guard let url = URL(string: string),
          let components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
      throw DeeplinkParserError.unsupportedDeeplink(string: string)
    }
    
    switch components.scheme {
    case "tonsign":
      guard let queryItems = components.queryItems,
            !queryItems.isEmpty else { return .tonsign(.plain) }
      
      guard let pk = queryItems.first(where: { $0.name == "pk" })?.value,
            let publicKeyData = Data(hex: pk),
            let body = queryItems.first(where: { $0.name == "body" })?.value,
            let bodyData = Data(hex: body) else {
        throw DeeplinkParserError.unsupportedDeeplink(string: string)
      }
      
      let publicKey = TonSwift.PublicKey(data: publicKeyData)
      
      let returnURL = queryItems.first(where: { $0.name == "return" })?.value
      let version = queryItems.first(where: { $0.name == "v" })?.value
      let network = queryItems.first(where: { $0.name == "network" })?.value

      return .tonsign(
        .sign(
          TonSignModel(
            publicKey: publicKey,
            body: bodyData,
            returnURL: returnURL,
            version: version,
            network: network
          )
        )
      )
    default:
      throw DeeplinkParserError.unsupportedDeeplink(string: string)
    }
  }
}
