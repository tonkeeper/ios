import Foundation

public struct FiatOperator: Identifiable {
  public struct InfoButton {
    public let title: String
    public let url: URL?
  }
  
  public let id: String
  public let title: String
  public let description: String
  public let rate: String
  public let badge: String?
  public let iconURL: URL?
  public let actionTemplateURL: String?
  public let infoButtons: [InfoButton]
  
  public init(id: String, 
              title: String,
              description: String,
              rate: String,
              badge: String?,
              iconURL: URL?,
              actionTemplateURL: String?,
              infoButtons: [InfoButton]) {
    self.id = id
    self.title = title
    self.description = description
    self.rate = rate
    self.badge = badge
    self.iconURL = iconURL
    self.actionTemplateURL = actionTemplateURL
    self.infoButtons = infoButtons
  }
}
