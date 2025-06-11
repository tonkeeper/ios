import Foundation

public struct TonConnectManifest: Codable, Equatable {
  public let url: URL
  public let name: String
  public let iconUrl: URL?
  public let termsOfUseUrl: URL?
  public let privacyPolicyUrl: URL?
  
  public var host: String {
    url.host ?? ""
  }
  
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.url = try container.decode(URL.self, forKey: .url)
    self.name = try container.decode(String.self, forKey: .name)

    if let iconUrlRaw = try container.decodeIfPresent(String.self, forKey: .iconUrl),
    let iconUrl = URL(string: iconUrlRaw) {
      self.iconUrl = iconUrl
    } else {
      self.iconUrl = nil
    }
    
    if let termsOfUseRaw = try container.decodeIfPresent(String.self, forKey: .termsOfUseUrl),
    let termsOfUseUrl = URL(string: termsOfUseRaw) {
      self.termsOfUseUrl = termsOfUseUrl
    } else {
      self.termsOfUseUrl = nil
    }
    
    if let privacyPolicyRaw = try container.decodeIfPresent(String.self, forKey: .privacyPolicyUrl),
    let privacyPolicyUrl = URL(string: privacyPolicyRaw) {
      self.privacyPolicyUrl = privacyPolicyUrl
    } else {
      self.privacyPolicyUrl = nil
    }
  }
}
