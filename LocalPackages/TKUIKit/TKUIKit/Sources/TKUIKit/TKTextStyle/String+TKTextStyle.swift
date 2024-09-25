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

public extension NSAttributedString {

  func applyVerificationAttachment(_ isVerified: Bool) -> NSAttributedString {
    guard isVerified else { return self }

    let image = Assets.Icons._16.icVerification16Gray.image

    let attachment = NSTextAttachment(image: image)
    let yOrigin = ((size().height / 2) - image.size.height) / 3
    attachment.bounds = CGRect(x: 0, y: yOrigin, width: image.size.width, height: image.size.height)
    let attachmentString = NSMutableAttributedString(attachment: attachment)
    attachmentString.addAttributes(
      [.foregroundColor: UIColor.Icon.secondary],
      range: NSRange(location: 0, length: attachmentString.length)
    )

    let resultMutableString = NSMutableAttributedString(attributedString: self)
    resultMutableString.append(NSAttributedString(string: " "))
    resultMutableString.append(attachmentString)
    return resultMutableString
  }
}
