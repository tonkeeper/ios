import Foundation
import TonSwift
import BigInt

enum DeeplinkParserError: Swift.Error {
  case unsupportedDeeplink(string: String?)
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

public struct TonDeeplinkParser: DeeplinkParser {
  public init() {}
  
  public func parse(string: String?) throws -> Deeplink {
    guard let string else { throw DeeplinkParserError.unsupportedDeeplink(string: string) }
    guard let url = URL(string: string),
          let scheme = url.scheme,
          let host = url.host else {
      throw DeeplinkParserError.unsupportedDeeplink(string: string)
    }
    
    let components = URLComponents(url: url, resolvingAgainstBaseURL: true)
    
    switch scheme {
    case "ton":
      switch host {
      case "transfer":
        let address = url.lastPathComponent
        var amount: BigUInt?
        var comment: String?
        var jettonAddress: Address?
        if let amountRawParameter = components?.queryItems?.first(where: { $0.name == "amount" })?.value,
           let amountParameter = BigUInt(amountRawParameter) {
          amount = amountParameter
        }
        if let commentParameter = components?.queryItems?.first(where: { $0.name == "text" })?.value {
          comment = commentParameter
        }
        if let jettonParameter = components?.queryItems?.first(where: { $0.name == "jetton" })?.value,
           let address = try? Address.parse(jettonParameter){
          jettonAddress = address
        }
        
        return .ton(.transfer(recipient: address, amount: amount, comment: comment, jettonAddress: jettonAddress))
      case "buy-ton":
        return .ton(.buyTon)
      case "staking":
        return .ton(.staking)
      default:
        throw DeeplinkParserError.unsupportedDeeplink(string: string)
      }
    default: throw DeeplinkParserError.unsupportedDeeplink(string: string)
    }
  }
}

public struct TonConnectDeeplinkParser: DeeplinkParser {
  public init() {}
  
  public func parse(string: String?) throws -> Deeplink {
    guard let string else { throw DeeplinkParserError.unsupportedDeeplink(string: string) }
    if let deeplink = try? parseTonConnectDeeplink(string: string) {
      return deeplink
    }
    if let universalLink = try? parseTonConnectUniversalLink(string: string) {
      return universalLink
    }
    throw DeeplinkParserError.unsupportedDeeplink(string: string)
  }
  
  private func parseTonConnectDeeplink(string: String) throws -> Deeplink {
    guard let url = URL(string: string),
          let scheme = url.scheme
    else { throw DeeplinkParserError.unsupportedDeeplink(string: string) }
    switch scheme {
    case "tc":
      return .tonConnect(.init(string: string))
    default: throw DeeplinkParserError.unsupportedDeeplink(string: string)
    }
  }
  
  private func parseTonConnectUniversalLink(string: String) throws -> Deeplink {
    guard let url = URL(string: string),
          let components = URLComponents(
            url: url,
            resolvingAgainstBaseURL: true
          ) else { throw DeeplinkParserError.unsupportedDeeplink(string: string) }
    switch url.path {
    case "/ton-connect":
      var tcComponents = URLComponents()
      tcComponents.scheme = "tc"
      tcComponents.queryItems = components.queryItems
      guard let string = tcComponents.string else {
        throw DeeplinkParserError.unsupportedDeeplink(string: string)
      }
      return .tonConnect(.init(string: string))
    default:
      throw DeeplinkParserError.unsupportedDeeplink(string: string)
    }
  }
}

public struct TonkeeperDeeplinkParser: DeeplinkParser {
  public init() {}
  
  public func parse(string: String?) throws -> Deeplink {
    guard let string,
          let url = URL(string: string),
          let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
          let scheme = components.scheme,
          let host = components.host,
          let queryItems = components.queryItems else {
      throw DeeplinkParserError.unsupportedDeeplink(string: string)
    }
    
    switch scheme {
    case "tonkeeper", "tonkeeperx":
      switch host {
      case "signer":
        return try signerParse(string: string, host: host, path: components.path, queryItems: queryItems)
      case "publish":
        guard let signHex = queryItems.first(where: { $0.name == "sign" })?.value,
              let signData = Data(hex: signHex) else {
          throw DeeplinkParserError.unsupportedDeeplink(string: string)
        }
        
        let model = TonkeeperPublishModel(
          sign: signData
        )
        
        return .tonkeeper(TonkeeperDeeplink.publish(model))
      default:
        throw DeeplinkParserError.unsupportedDeeplink(string: string)
      }
    default:
      throw DeeplinkParserError.unsupportedDeeplink(string: string)
    }
  }
  
  func signerParse(string: String, host: String, path: String, queryItems: [URLQueryItem]) throws -> Deeplink {
    switch path {
    case "/link":
      guard let pkHex = queryItems.first(where: { $0.name == "pk" })?.value,
            let pkData = Data(hex: pkHex),
            let name = queryItems.first(where: { $0.name == "name" })?.value else {
        throw DeeplinkParserError.unsupportedDeeplink(string: string)
      }
      let publicKey = TonSwift.PublicKey(data: pkData)
      return .tonkeeper(TonkeeperDeeplink.signer(.link(publicKey: publicKey, name: name)))
    default:
      throw DeeplinkParserError.unsupportedDeeplink(string: string)
    }
  }
}
