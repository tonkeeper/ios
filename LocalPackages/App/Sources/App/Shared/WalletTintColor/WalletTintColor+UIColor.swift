import UIKit
import TKUIKit
import KeeperCore

extension WalletTintColor {
  var uiColor: UIColor {
    switch self {
    case .SteelGray:
      UIColor { traitCollection in
        switch TKThemeManager.shared.theme {
        case .deepBlue:
          UIColor(hex: "293342")
        case .dark:
          UIColor(hex: "2F2F33")
        case .light:
          UIColor(hex: "818C99")
        case .system:
          switch traitCollection.userInterfaceStyle {
          case .dark:
            UIColor(hex: "2F2F33")
          case .light:
            UIColor(hex: "818C99")
          case .unspecified:
            UIColor(hex: "818C99")
          @unknown default:
            UIColor(hex: "2F2F33")
          }
        }
      }
    case .LightSteelGray:
      UIColor { traitCollection in
        switch TKThemeManager.shared.theme {
        case .deepBlue:
          UIColor(hex: "424C5C")
        case .dark:
          UIColor(hex: "4E4E52")
        case .light:
          UIColor(hex: "95A0AD")
        case .system:
          switch traitCollection.userInterfaceStyle {
          case .dark:
            UIColor(hex: "4E4E52")
          case .light:
            UIColor(hex: "95A0AD")
          case .unspecified:
            UIColor(hex: "95A0AD")
          @unknown default:
            UIColor(hex: "4E4E52")
          }
        }
      }
    case .Gray:
      UIColor { traitCollection in
        switch TKThemeManager.shared.theme {
        case .deepBlue:
          UIColor(hex: "9DA2A4")
        case .dark:
          UIColor(hex: "8D8D93")
        case .light:
          UIColor(hex: "B6BBC2")
        case .system:
          switch traitCollection.userInterfaceStyle {
          case .dark:
            UIColor(hex: "8D8D93")
          case .light:
            UIColor(hex: "B6BBC2")
          case .unspecified:
            UIColor(hex: "B6BBC2")
          @unknown default:
            UIColor(hex: "8D8D93")
          }
        }
      }
    case .LightRed:
      UIColor(hex: "FF8585")
    case .LightOrange:
      UIColor(hex: "FFA970")
    case .LightYellow:
      UIColor(hex: "FFC95C")
    case .LightGreen:
      UIColor(hex: "85CC7A")
    case .LightBlue:
      UIColor(hex: "70A0FF")
    case .LightAquamarine:
      UIColor(hex: "6CCCF5")
    case .LightPurple:
      UIColor(hex: "AD89F5")
    case .LightViolet:
      UIColor(hex: "F57FF5")
    case .LightMagenta:
      UIColor(hex: "F576B1")
    case .LightFireOrange:
      UIColor(hex: "F57F87")
    case .Red:
      UIColor(hex: "FF5252")
    case .Orange:
      UIColor(hex: "FF8B3D")
    case .Yellow:
      UIColor(hex: "FFB92E")
    case .Green:
      UIColor(hex: "69CC5A")
    case .Blue:
      UIColor(hex: "528BFF")
    case .Aquamarine:
      UIColor(hex: "47C8FF")
    case .Purple:
      UIColor(hex: "925CFF")
    case .Violet:
      UIColor(hex: "FF5CFF")
    case .Magenta:
      UIColor(hex: "FF479D")
    case .FireOrange:
      UIColor(hex: "FF525D")
    }
  }
}
