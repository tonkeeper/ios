import Foundation

public extension KeeperInfo {
  struct AppSettings: Equatable {
    public let isSecureMode: Bool
    public let searchEngine: SearchEngine
    
    public init(isSecureMode: Bool, searchEngine: SearchEngine) {
      self.isSecureMode = isSecureMode
      self.searchEngine = searchEngine
    }
  }
}

extension KeeperInfo.AppSettings: Codable {
  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.isSecureMode = (try? container.decode(Bool.self, forKey: .isSecureMode)) ?? false
    if let selectedSearchEngine = try container.decodeIfPresent(SearchEngine.self, forKey: .searchEngine) {
      self.searchEngine = selectedSearchEngine
    } else {
      self.searchEngine = .duckduckgo
    }
  }
}
