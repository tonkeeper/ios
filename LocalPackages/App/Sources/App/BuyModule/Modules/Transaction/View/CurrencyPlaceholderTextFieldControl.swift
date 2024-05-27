import Foundation
import TKUIKit

public class CurrencyPlaceholderTextFieldControl: TKTextInputTextFieldControl {
  public override func rightViewRect(forBounds bounds: CGRect) -> CGRect {
    let rect = super.rightViewRect(forBounds: bounds)
    guard let font = self.font, let text = self.text, !text.isEmpty else {
      return .zero
    }
    let fontAttributes = [NSAttributedString.Key.font: font]
    let size = (text as NSString).size(withAttributes: fontAttributes)
    let maxAllowedOffset = bounds.width - rect.width
    let offset = min(size.width + .rightViewOffset, maxAllowedOffset)
    return CGRect(x: offset, y: rect.origin.y + .verticalOriginOffset, width: rect.width, height: rect.height)
  }
}

private extension CGFloat {
  static let rightViewOffset: CGFloat = 4
  static let verticalOriginOffset: CGFloat = 0.3
}
