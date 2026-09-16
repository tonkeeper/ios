import SwiftUI
import UIKit

struct ChartPriceText: View {
    static let foregroundColor: TKColor = .textSecondary

    let priceText: String
    let textStyle: TKTextStyle

    var body: some View {
        Text(attributedPriceText)
            .foregroundStyle(Self.foregroundColor)
    }

    private var attributedPriceText: AttributedString {
        let styled = priceText
            .withTextStyle(
                textStyle,
                color: .clear,
                alignment: .right,
                lineBreakMode: .byTruncatingTail
            )
            .replacingThinSpaces(
                font: .monospacedDigitSystemFont(
                    ofSize: textStyle.font.pointSize,
                    weight: .medium
                )
            )
        let result = NSMutableAttributedString(attributedString: styled)
        result.removeAttribute(.foregroundColor, range: NSRange(location: 0, length: result.length))
        return AttributedString(result)
    }
}

private extension NSAttributedString {
    func replacingThinSpaces(font: UIFont) -> NSAttributedString {
        let string = self.string as NSString
        let result = NSMutableAttributedString(attributedString: self)
        var searchRange = NSRange(location: 0, length: string.length)

        while searchRange.length > 0 {
            let range = string.range(
                of: "\u{2009}",
                options: [],
                range: searchRange
            )
            guard range.location != NSNotFound else {
                break
            }

            result.addAttributes([.font: font], range: range)

            let nextLocation = range.location + range.length
            searchRange = NSRange(
                location: nextLocation,
                length: string.length - nextLocation
            )
        }

        return result
    }
}
