import UIKit

struct WalletHeaderBannerModel {
  enum Appearance {
    case regular
    
    var tintColor: UIColor {
      switch self {
      case .regular: return .Text.primary
      }
    }
    
    var descriptionColor: UIColor {
      switch self {
      case .regular: return .Text.secondary
      }
    }
    
    var backgroundColor: UIColor {
      switch self {
      case .regular: return .Background.contentTint
      }
    }
  }
  let identifier: String
  let title: String
  let description: String?
  let appearance: Appearance
}
