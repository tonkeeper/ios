import Foundation

public struct InternalNotification: Decodable, Equatable, Hashable {
  public enum Mode: String, Codable {
    case warning
  }
  
  public struct Action: Decodable, Equatable {
    public enum ActionType: Codable, Equatable {
      case openLink(URL?)
      case unknown
    }
    
    public let type: ActionType
    public let label: String
    
    private enum CodingKeys: String, CodingKey {
      case type
      case label
      case url
    }
    
    public init(from decoder: any Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      self.label = try container.decode(String.self, forKey: .label)
      
      let typeRaw = try container.decode(String.self, forKey: .type)
      switch typeRaw {
      case "open_link":
        let urlString = try container.decode(String.self, forKey: .url)
        self.type = .openLink(URL(string: urlString))
      default:
        self.type = .unknown
      }
    }
  }
  
  public let id: String
  public let title: String
  public let caption: String
  public let mode: Mode
  public let action: Action
  
  public func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }
}

public struct InternalNotificationResponse: Decodable {
  public let notifications: [InternalNotification]
}
