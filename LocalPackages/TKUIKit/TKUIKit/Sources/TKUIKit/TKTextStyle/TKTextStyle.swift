import UIKit

public struct TKTextStyle: Hashable {
  public let font: UIFont
  public let lineHeight: CGFloat
  public let uppercased: Bool
  public let underline: Bool
  
  public var adjustment: CGFloat {
    lineHeight > font.lineHeight ? 2.0 : 1.0
  }
  
  public var baselineOffset: CGFloat {
    let delimeter: CGFloat
    if #available(iOS 16.4, *) {
      delimeter = 2
    } else {
      delimeter = 4
    }
    return (lineHeight - font.lineHeight) / delimeter
  }
  
  public var lineSpacing: CGFloat {
    return lineHeight - font.lineHeight
  }
  
  public init(font: UIFont,
              lineHeight: CGFloat,
              uppercased: Bool = false,
              underline: Bool = false) {
    self.font = font
    self.lineHeight = lineHeight
    self.uppercased = uppercased
    self.underline = underline
  }
  
  public func getAttributes(color: UIColor,
                            alignment: NSTextAlignment = .left,
                            lineBreakMode: NSLineBreakMode = .byTruncatingTail) -> [NSAttributedString.Key: Any] {
    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.minimumLineHeight = lineHeight
    paragraphStyle.maximumLineHeight = lineHeight
    paragraphStyle.alignment = alignment
    paragraphStyle.lineBreakMode = lineBreakMode

    var attributes: [NSAttributedString.Key: Any] = [
      .font: font,
      .foregroundColor: color,
      .paragraphStyle: paragraphStyle,
      .baselineOffset: baselineOffset,
    ]
    if underline {
      attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
    }
    
    return attributes
  }

  public func getTabStyledAttributes(color: UIColor,
                                     alignment: NSTextAlignment = .left,
                                     lineBreakMode: NSLineBreakMode = .byTruncatingTail) -> [NSAttributedString.Key: Any] {
    let paragraphStyle = NSMutableParagraphStyle()
    let bulletSize = NSAttributedString(string: "•", attributes: [.font: font]).size()
    let itemStart = bulletSize.width + 8
    paragraphStyle.headIndent = itemStart
    paragraphStyle.tabStops = [NSTextTab(textAlignment: .left, location: itemStart)]
    paragraphStyle.minimumLineHeight = lineHeight
    paragraphStyle.maximumLineHeight = lineHeight
    paragraphStyle.alignment = alignment
    paragraphStyle.lineBreakMode = lineBreakMode

    var attributes: [NSAttributedString.Key: Any] = [
      .font: font,
      .foregroundColor: color,
      .paragraphStyle: paragraphStyle,
      .baselineOffset: baselineOffset,
    ]
    if underline {
      attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
    }

    return attributes
  }
}

public extension TKTextStyle {
  static let balance = TKTextStyle(
    font: .montserratSemiBold(size: 44),
    lineHeight: 56
  )
  
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
  
  static let body3Alternate: TKTextStyle = .init(
    font: .montserratMedium(size: 13),
    lineHeight: 16
  )
  
  static let body4: TKTextStyle = .init(
    font: .montserratSemiBold(size: 10),
    lineHeight: 14,
    uppercased: true
  )
}
