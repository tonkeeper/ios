import Foundation

public struct Dapp: Codable, Equatable {
  public let name: String
  public let description: String?
  public let icon: URL?
  public let poster: URL?
  public let url: URL
  public let textColor: String?
  
  public static func ==(lhs: Dapp, rhs: Dapp) -> Bool {
    lhs.url.host == rhs.url.host
  }
  
  public init(name: String,
              description: String?,
              icon: URL?,
              poster: URL?,
              url: URL,
              textColor: String?) {
    self.name = name
    self.description = description
    self.icon = icon
    self.poster = poster
    self.url = url
    self.textColor = textColor
  }
}
