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
      stakingInfoUrl: nil
    )
  }
}
