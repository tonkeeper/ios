import KeeperCore
import TKUIKit
import UIKit

public extension Wallet {
    func iconWithName(
        attributes: [NSAttributedString.Key: Any],
        iconColor: UIColor,
        iconSide: CGFloat
    ) -> NSAttributedString {
        switch self.icon {
        case let .emoji(emoji):
            let name = "\(emoji) \(label)"
            return NSAttributedString(string: name, attributes: attributes)
        case let .icon(icon):
            let result = NSMutableAttributedString()
            if let image = icon.image {
                let attachment = NSTextAttachment(image: image)
                let iconOriginY = (image.size.height - iconSide) / 2
                attachment.bounds = CGRect(origin: CGPoint(x: 0, y: iconOriginY), size: CGSize(width: iconSide, height: iconSide))
                let attachmentString = NSMutableAttributedString(attachment: attachment)
                attachmentString.append(NSAttributedString(string: " "))
                attachmentString.addAttributes(
                    [.foregroundColor: iconColor],
                    range: NSRange(
                        location: 0,
                        length: attachmentString.length
                    )
                )
                result.append(attachmentString)
            }
            result.append(NSAttributedString(string: label, attributes: attributes))
            return result
        }
    }
}
