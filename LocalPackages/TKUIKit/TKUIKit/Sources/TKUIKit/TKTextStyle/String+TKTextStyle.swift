import Foundation
import UIKit.NSParagraphStyle

public extension String {

  func withTextStyle(_ textStyle: TKTextStyle,
                     color: UIColor,
                     alignment: NSTextAlignment = .left,
                     lineBreakMode: NSLineBreakMode = .byTruncatingTail) -> NSAttributedString {
    let string = textStyle.uppercased ? uppercased() : self
    return NSAttributedString(
      string: string,
      attributes: textStyle.getAttributes(
        color: color,
        alignment: alignment,
        lineBreakMode: lineBreakMode
      )
    )
  }
}
