import Foundation

public struct FiatMethodItem: Codable {
  public typealias ID = String
  
  struct ActionButton: Codable {
    let title: String
    let url: String
    
    enum CodingKeys: String, CodingKey {
      case title
      case url
    }
  }
  
  let id: ID
  public let title: String
  let isDisabled: Bool?
  let badge: String?
  let subtitle: String?
  let description: String?
  public let iconURL: URL?
  let actionButton: ActionButton
  let infoButtons: [ActionButton]
  
  enum CodingKeys: String, CodingKey {
    case id
    case title
    case isDisabled = "disabled"
    case badge
    case subtitle
    case description
    case iconURL = "icon_url"
    case actionButton = "action_button"
    case infoButtons = "info_buttons"
  }
}

public struct FiatMethodCategory: Codable {
  enum CategoryType: String, Codable {
    case buy
    case sell
  }
  
  let type: CategoryType
  let title: String?
  let subtitle: String?
  let items: [FiatMethodItem]
}

public struct FiatMethodLayout: Codable {
  public let countryCode: String?
  public let currency: String?
  public let methods: [FiatMethodItem.ID]
}

public struct FiatMethods: Codable {
  public let layoutByCountry: [FiatMethodLayout]
  public let defaultLayout: FiatMethodLayout
  public let categories: [FiatMethodCategory]
}

struct FiatMethodsResponse: Codable {
  let data: FiatMethods
}
