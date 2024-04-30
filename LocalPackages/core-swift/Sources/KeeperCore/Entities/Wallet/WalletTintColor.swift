import Foundation

public enum WalletTintColor: String, Codable, CaseIterable {
  case steelGray = "293342"
  case lightSteelGray = "424C5C"
  case gray = "9DA2A4"
  case lightRed = "FF8585"
  case lightOrange = "FFA970"
  case lightYellow = "FFC95C"
  case lightGreen = "85CC7A"
  case lightBlue = "70A0FF"
  case lightAquamarine = "6CCCF5"
  case lightPurple = "AD89F5"
  case lightViolet = "F57FF5"
  case lightMagenta = "F576B1"
  case lightFireOrange = "F57F87"
  case red = "FF5252"
  case orange = "FF8B3D"
  case yellow = "FFB92E"
  case green = "69CC5A"
  case blue = "528BFF"
  case aquamarine = "47C8FF"
  case purple = "925CFF"
  case violet = "FF5CFF"
  case magenta = "FF479D"
  case fireOrange = "FF525D"
  
  public static var defaultColor: WalletTintColor {
    .steelGray
  }
}
