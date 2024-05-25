import Foundation
import BigInt
           
public enum FiatMethodCategoryType: String, Codable, CaseIterable {
  case buy
  case sell
}

struct FiatMethodItem: Codable {
  typealias ID = String
  
  struct ActionButton: Codable {
    let title: String
    let url: String
    
    enum CodingKeys: String, CodingKey {
      case title
      case url
    }
  }
  
  let id: ID
  let title: String
  let isDisabled: Bool?
  let badge: String?
  let subtitle: String?
  let description: String?
  let iconURL: URL?
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

struct FiatMethodCategory: Codable {
  let type: FiatMethodCategoryType
  let title: String?
  let subtitle: String?
  let items: [FiatMethodItem]
}

struct FiatMethodLayout: Codable {
  let countryCode: String?
  let currency: String?
  let methods: [FiatMethodItem.ID]
}

struct FiatMethods: Codable {
  let layoutByCountry: [FiatMethodLayout]
  let defaultLayout: FiatMethodLayout
  let categories: [FiatMethodCategory]
}

struct FiatMethodsResponse: Codable {
  let data: FiatMethods
}
