import Foundation

public struct Story: Decodable, Equatable {
  public struct Page: Decodable, Equatable {
    public struct Button: Decodable, Equatable {
      public enum ButtonType: String {
        case deeplink
        case link
        
        public init?(rawValue: String) {
          switch rawValue.lowercased() {
          case "deeplink":
            self = .deeplink
          case "link":
            self = .link
          default:
            return nil
          }
        }
      }
      
      public let title: String
      public let payload: String
      public let type: ButtonType
      
      enum CodingKeys: String, CodingKey {
        case title
        case payload
        case type
      }
      
      public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        title = try container.decode(String.self, forKey: .title)
        payload = try container.decode(String.self, forKey: .payload)
        
        let typeString = try container.decode(String.self, forKey: .type)
        guard let buttonType = ButtonType(rawValue: typeString) else {
          throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Invalid button type")
        }
        
        type = buttonType
      }
    }
    
    public let title: String
    public let description: String
    public let image: String
    public let button: Button?
  }
  
  public let pages: [Page]
}
