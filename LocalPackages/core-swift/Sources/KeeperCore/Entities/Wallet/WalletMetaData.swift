import Foundation

public struct WalletMetaData: Codable {
  public let label: String
  public let tintColor: WalletTintColor
  public let icon: WalletIcon
  
  public init(label: String,
              tintColor: WalletTintColor,
              icon: WalletIcon) {
    self.label = label
    self.tintColor = tintColor
    self.icon = icon
  }
}

public enum WalletIcon: Codable, Equatable {
  case emoji(String)
  case icon(Image)
  
  public enum Image: String, Codable, CaseIterable {
    case wallet
    case leaf
    case lock
    case key
    case inbox
    case snowflake
    case sparkles
    case sun
    case hare
    case flash
    case bankCard
    case gear
    case handRaised
    case magnifyingGlassCircle
    case flashCircle
    case dollarCircle
    case euroCircle
    case sterlingCircle
    case yuanCircle
    case rubleCircle
    case indianRupeeCircle
  }
}

public enum WalletTintColor: String, Codable, CaseIterable {
  case SteelGray
  case LightSteelGray
  case Gray
  case LightRed
  case LightOrange
  case LightYellow
  case LightGreen
  case LightBlue
  case LightAquamarine
  case LightPurple
  case LightViolet
  case LightMagenta
  case LightFireOrange
  case Red
  case Orange
  case Yellow
  case Green
  case Blue
  case Aquamarine
  case Purple
  case Violet
  case Magenta
  case FireOrange
  
  public static var defaultColor: WalletTintColor {
    .SteelGray
  }
}

