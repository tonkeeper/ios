import Foundation
import TonSwift
import BigInt

public struct TonkeeperDeeplinkParser {
  public func parse(string: String?) throws -> Deeplink {
    guard let string,
          let url = URL(string: string),
          let firstPathComponent = url.pathComponents.first else {
      throw DeeplinkParserError.unsupportedDeeplink(string: string)
    }
    
    switch firstPathComponent {
    case "transfer":
      return .transfer(try parseTransfer(url: url))
    case "buy-ton":
      return .buyTon
    case "staking":
      return .staking
    case "pool":
      return .pool(try parsePool(url: url))
    case "exchange":
      return .exchange(provider: parseExchange(url: url))
    case "swap":
      return .swap(parseSwap(url: url))
    case "action":
      return .action(eventId: parseAction(url: url))
    case "publish":
      return .publish(sign: try parsePublish(url: url))
    case "signer":
      return .externalSign(try parseExternalSign(url: url))
    case "ton-connect":
      return .tonconnect(try parseTonconnect(url: url))
    case "dapp":
      return .dapp(try parseDapp(url: url))
    case "battery":
      return .battery(parseBattery(url: url))
    default:
      throw DeeplinkParserError.unsupportedDeeplink(string: string)
    }
  }
  
  func parseTransfer(url: URL) throws -> Deeplink.TransferData {
    let components = URLComponents(
      url: url,
      resolvingAgainstBaseURL: true
    )
    
    let recipient: String = try {
      guard url.pathComponents.count > 1 else {
        throw DeeplinkParserError.invalidParameters
      }
      let recipientParameter = url.pathComponents[1]
      return recipientParameter
    }()
    
    let amount: BigUInt? = {
      guard let amountParameter = components?.queryItems?.first(where: { $0.name == "amount" })?.value else {
        return nil
      }
      return BigUInt(amountParameter)
    }()
    
    let comment: String? = {
      components?.queryItems?.first(where: { $0.name == "text" })?.value
    }()
    
    let jettonAddress: Address? = {
      guard let jettonAddressParameter = components?.queryItems?.first(where: { $0.name == "jetton" })?.value else {
        return nil
      }
      return try? Address.parse(jettonAddressParameter)
    }()

    let expirationTimestamp: Int64? = {
      guard let exp = components?.queryItems?.first(where: { $0.name == "exp" })?.value else {
        return nil
      }
      return Int64(exp)
    }()

    return Deeplink.TransferData(
      recipient: recipient,
      amount: amount,
      comment: comment,
      jettonAddress: jettonAddress,
      expirationTimestamp: expirationTimestamp
    )
  }
  
  func parsePool(url: URL) throws -> Address {
    try Address.parse(url.lastPathComponent)
  }
  
  func parseExchange(url: URL) -> String {
    url.lastPathComponent
  }
  
  func parseSwap(url: URL) -> Deeplink.SwapData {
    let components = URLComponents(
      url: url,
      resolvingAgainstBaseURL: true
    )
    let fromToken = components?.queryItems?.first(where: { $0.name == "ft" })?.value
    let toToken = components?.queryItems?.first(where: { $0.name == "tt" })?.value
    return Deeplink.SwapData(
      fromToken: fromToken,
      toToken: toToken
    )
  }
  
  func parseAction(url: URL) -> String {
    url.lastPathComponent
  }
  
  func parseTonconnect(url: URL) throws -> TonConnectParameters {
    let components = URLComponents(
      url: url,
      resolvingAgainstBaseURL: true
    )
    
    guard let versionParameter = components?.queryItems?.first(where: { $0.name == "v" })?.value,
          let version = TonConnectParameters.Version(rawValue: versionParameter),
          let clientId = components?.queryItems?.first(where: { $0.name == "id" })?.value,
          let returnStrategy = components?.queryItems?.first(where: { $0.name == "ret" })?.value,
          let requestPayloadValue = components?.queryItems?.first(where: { $0.name == "r" })?.value,
          let requestPayloadData = requestPayloadValue.data(using: .utf8),
          let requestPayload = try? JSONDecoder().decode(TonConnectRequestPayload.self, from: requestPayloadData)
    else {
      throw DeeplinkParserError.invalidParameters
    }
      
    return TonConnectParameters(
      version: version,
      clientId: clientId,
      requestPayload: requestPayload,
      returnStrategy: returnStrategy)
  }
  
  func parsePublish(url: URL) throws -> Data {
    let components = URLComponents(
      url: url,
      resolvingAgainstBaseURL: true
    )
    
    guard let signHex = components?.queryItems?.first(where: { $0.name == "sign" })?.value,
          let signData = Data(hex: signHex) else {
      throw DeeplinkParserError.invalidParameters
    }
    
    return signData
  }
  
  func parseExternalSign(url: URL) throws -> ExternalSignDeeplink {
    let components = URLComponents(
      url: url,
      resolvingAgainstBaseURL: true
    )
    switch components?.path {
    case "signer/link":
      guard let pkHex = components?.queryItems?.first(where: { $0.name == "pk" })?.value,
            let pkData = Data(hex: pkHex),
            let name = components?.queryItems?.first(where: { $0.name == "name" })?.value else {
        throw DeeplinkParserError.invalidParameters
      }
      let publicKey = TonSwift.PublicKey(data: pkData)
      return ExternalSignDeeplink.link(publicKey: publicKey, name: name)
    default:
      throw DeeplinkParserError.unsupportedDeeplink(string: url.absoluteString)
    }
  }

  private func parseDapp(url: URL) throws -> URL {
    let dappPrefix = "dapp/"
    var stringURL = url.absoluteString

    if stringURL.hasPrefix(dappPrefix) {
      stringURL = String(stringURL.dropFirst(dappPrefix.count))
    }

    let httpsPrefix = "https://"
    if !stringURL.hasPrefix(httpsPrefix) {
      stringURL = "\(httpsPrefix)\(stringURL)"
    }

    let components = URLComponents(string: "\(stringURL)")

    guard let resultURL = components?.url else {
      throw DeeplinkParserError.unsupportedDeeplink(string: url.absoluteString)
    }

    return resultURL
  }
  
  private func parseBattery(url: URL) -> Deeplink.Battery {
    let components = URLComponents(
      url: url,
      resolvingAgainstBaseURL: true
    )
    
    let promocode = components?.queryItems?.first(where: { $0.name == "promocode" })?.value
    return Deeplink.Battery(promocode: promocode)
  }
}
