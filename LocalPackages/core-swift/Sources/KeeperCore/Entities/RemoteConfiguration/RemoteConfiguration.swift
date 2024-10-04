import Foundation

public struct RemoteConfiguration: Equatable {
  public let tonapiV2Endpoint: String
  public let tonapiTestnetHost: String
  public let tonApiV2Key: String
  public let mercuryoSecret: String?
  public let supportLink: URL?
  public let directSupportUrl: URL?
  public let tonkeeperNewsUrl: URL?
  public let stonfiUrl: URL?
  public let faqUrl: URL?
  public let stakingInfoUrl: URL?
  public let flags: Flags
  
  enum CodingKeys: String, CodingKey {
    case tonapiV2Endpoint
    case tonapiTestnetHost
    case tonApiV2Key
    case mercuryoSecret
    case supportLink
    case directSupportUrl
    case tonkeeperNewsUrl
    case stonfiUrl
    case faqUrl = "faq_url"
    case stakingInfoUrl
    case flags
  }
}

public extension RemoteConfiguration {
  struct Flags: Codable, Equatable {
    public let isSwapDisable: Bool
    public let isExchangeMethodsDisable: Bool
    public let isDappsDisable: Bool
    
    static var `default`: Flags {
      Flags(
        isSwapDisable: true,
        isExchangeMethodsDisable: true,
        isDappsDisable: true
      )
    }
    
    enum CodingKeys: String, CodingKey {
      case isSwapDisable = "disable_swap"
      case isExchangeMethodsDisable = "disable_exchange_methods"
      case isDappsDisable = "disable_dapps"
    }
  }
}

extension RemoteConfiguration: Codable {}

extension RemoteConfiguration {
  static var empty: RemoteConfiguration {
    RemoteConfiguration(
      tonapiV2Endpoint: "",
      tonapiTestnetHost: "",
      tonApiV2Key: "",
      mercuryoSecret: nil,
      supportLink: nil,
      directSupportUrl: nil,
      tonkeeperNewsUrl: nil,
      stonfiUrl: nil,
      faqUrl: nil,
      stakingInfoUrl: nil,
      flags: .default
    )
  }
}
