import UIKit

public struct TKTextStyle {
  public let font: UIFont
  public let lineHeight: CGFloat
  public let uppercased: Bool
  
  init(font: UIFont,
       lineHeight: CGFloat,
       uppercased: Bool = false) {
    self.font = font
    self.lineHeight = lineHeight
    self.uppercased = uppercased
  }
}

public extension TKTextStyle {
  static let num1: TKTextStyle = .init(
    font: .montserratSemiBold(size: 32),
    lineHeight: 40
  )
  
  static let h1: TKTextStyle = .init(
    font: .montserratBold(size: 32),
    lineHeight: 40
  )
  
  static let num2: TKTextStyle = .init(
    font: .montserratSemiBold(size: 28),
    lineHeight: 36
  )
  
  static let h2: TKTextStyle = .init(
    font: .montserratBold(size: 24),
    lineHeight: 32)
  
  static let h3: TKTextStyle = .init(
    font: .montserratBold(size: 20),
    lineHeight: 28
  )
  
  static let label1: TKTextStyle = .init(
    font: .montserratSemiBold(size: 16),
    lineHeight: 24
  )
  
  static let label2: TKTextStyle = .init(
    font: .montserratSemiBold(size: 14),
    lineHeight: 20
  )
  
  static let label3: TKTextStyle = .init(
    font: .montserratSemiBold(size: 12),
    lineHeight: 16
  )
  
  static let body1: TKTextStyle = .init(
    font: .montserratMedium(size: 16),
    lineHeight: 24
  )
  
  static let body2: TKTextStyle = .init(
    font: .montserratMedium(size: 14),
    lineHeight: 20
  )
  
  static let body3: TKTextStyle = .init(
    font: .montserratMedium(size: 12),
    lineHeight: 16
  )
  
  static let body4: TKTextStyle = .init(
    font: .montserratSemiBold(size: 10),
    lineHeight: 14,
    uppercased: true
  )
}
