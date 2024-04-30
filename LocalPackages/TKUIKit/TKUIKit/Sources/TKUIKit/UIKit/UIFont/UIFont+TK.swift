import UIKit

public extension UIFont {
  static func montserratBold(size: CGFloat) -> UIFont {
    font(.bold, size: size) ?? .systemFont(ofSize: size, weight: .bold)
  }
  
  static func montserratSemiBold(size: CGFloat) -> UIFont {
    font(.semibold, size: size) ?? .systemFont(ofSize: size, weight: .semibold)
  }

  static func montserratMedium(size: CGFloat) -> UIFont {
    font(.medium, size: size) ?? .systemFont(ofSize: size, weight: .medium)
  }
  
  private static func font(_ font: MontserratFont, size: CGFloat) -> UIFont? {
    let font = UIFont(name: font.name, size: size)
    assert(font != nil, "Can't load font")
    return font
  }
}
