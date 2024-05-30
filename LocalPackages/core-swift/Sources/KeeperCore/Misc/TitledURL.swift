import Foundation

public struct TitledURL {
  public let title: String
  public let url: URL
  
  public init(title: String, url: URL) {
    self.title = title
    self.url = url
  }
  
  public init?(title: String, url: URL?) {
    self.title = title
    guard let url else { return nil }
    self.url = url
  }
}
