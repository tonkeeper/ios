import UIKit

struct WalletHeaderBannerModel {
  struct ActionButton {
    let title: String
    let action: (() -> Void)
  }
  enum Appearance {
    case regular
    case accentBlue
    
    var tintColor: UIColor {
      switch self {
      case .regular: return .Text.primary
      case .accentBlue: return .Text.primary
      }
    }
    
    var descriptionColor: UIColor {
      switch self {
      case .regular: return .Text.secondary
      case .accentBlue: return .Text.primary
      }
    }
    
    var backgroundColor: UIColor {
      switch self {
      case .regular: return .Background.contentTint
      case .accentBlue: return .Accent.blue
      }
    }
  }
  let identifier: String
  let title: String?
  let description: String?
  let appearance: Appearance
  let actionButton: ActionButton?
  let closeButtonAction: (() -> Void)?
  
  init(identifier: String,
       title: String?,
       description: String?,
       appearance: Appearance,
       actionButton: ActionButton? = nil,
       closeButtonAction: (() -> Void)? = nil) {
    self.identifier = identifier
    self.title = title
    self.description = description
    self.appearance = appearance
    self.actionButton = actionButton
    self.closeButtonAction = closeButtonAction
  }
}
