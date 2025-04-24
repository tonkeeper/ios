import Foundation
import TonSwift
import BigInt

enum DeeplinkParserError: Swift.Error, LocalizedError {
  case unsupportedDeeplink(string: String?)
  case invalidParameters
  case unknownQueryItem(name: String)
  
  var errorDescription: String? {
    switch self {
    case .unsupportedDeeplink:
      "Unsupported deeplink"
    case .invalidParameters:
      "Invalid parameters"
    case .unknownQueryItem(let name):
      "Unknown parameter \(name)"
    }
  }
}

public struct DeeplinkParser {
  
  private let tonkeeperParser = TonkeeperDeeplinkParser()
  
  public init() {}
  
  public func parse(string: String?) throws -> Deeplink {
    guard let string,
          !string.isEmpty else {
      throw DeeplinkParserError.unsupportedDeeplink(string: string)
    }
    
    if let tonconnectDeeplink = parseTonconnectDeeplink(string: string) {
      return tonconnectDeeplink
    }
    
    let deeplinkPrefixes = [
      "ton://",
      "tonkeeper://",
      "tonkeeper-mob://",
      "tonkeeperx://",
      "https://app.tonkeeper.com/",
      "https://tonhub.com/",
      "tonkeeper-mob://",
      "tonkeeper-tc-mob://"
    ]
    
    guard let prefix = deeplinkPrefixes.first(where: { string.hasPrefix($0) }) else {
      throw DeeplinkParserError.unsupportedDeeplink(string: string)
    }
    
    let prefixIndex = string.index(string.startIndex, offsetBy: prefix.count)
    let unprefixedString = String(string[prefixIndex...])
    
    return try tonkeeperParser.parse(string: unprefixedString)
  }
  
  private func parseTonconnectDeeplink(string: String) -> Deeplink? {
    let tonconnectDeeplinkPrefixes = [
      "tc://",
      "tonkeeper-tc://",
      "tonkeeper-tc-mob://"
    ]
    
    guard let prefix = tonconnectDeeplinkPrefixes.first(where: { string.hasPrefix($0) }) else {
      return nil
    }

    let prefixIndex = string.index(string.startIndex, offsetBy: prefix.count)
    let unprefixedString = String(string[prefixIndex...])
    guard let url = URL(string: unprefixedString) else { return nil }
    
    do {
      return .tonconnect(try tonkeeperParser.parseTonconnect(url: url))
    } catch {
      return nil
    }
  }
}
