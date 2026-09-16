import UIKit

public struct TKTextStyle: Hashable, Sendable {
    public let font: UIFont
    public let lineHeight: CGFloat
    public let letterSpacing: CGFloat
    public let uppercased: Bool
    public let underline: Bool

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

    public init(
        font: UIFont,
        lineHeight: CGFloat,
        letterSpacing: CGFloat = 0,
        uppercased: Bool = false,
        underline: Bool = false
    ) {
        self.font = font
        self.lineHeight = lineHeight
        self.letterSpacing = letterSpacing
        self.uppercased = uppercased
        self.underline = underline
    }

    public func getAttributes(
        color: UIColor,
        alignment: NSTextAlignment = .left,
        lineBreakMode: NSLineBreakMode = .byTruncatingTail
    ) -> [NSAttributedString.Key: Any] {
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
            .kern: letterSpacing,
        ]
        if underline {
            attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
        }

        return attributes
    }

    public func getTabStyledAttributes(
        color: UIColor,
        alignment: NSTextAlignment = .left,
        lineBreakMode: NSLineBreakMode = .byTruncatingTail
    ) -> [NSAttributedString.Key: Any] {
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
            .kern: letterSpacing,
        ]
        if underline {
            attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
        }

        return attributes
    }
}

public extension TKTextStyle {
    /// Same style with tabular lining figures, so live countdowns and amounts don't jitter.
    /// `UIFont.monospacedDigits()` only adds feature settings, so ascender, descender and
    /// therefore `lineSpacing` are untouched and the style stays interchangeable with its base.
    func monospacedDigits() -> TKTextStyle {
        TKTextStyle(
            font: font.monospacedDigits(),
            lineHeight: lineHeight,
            letterSpacing: letterSpacing,
            uppercased: uppercased,
            underline: underline
        )
    }
}

public extension TKTextStyle {
    static let balance = TKTextStyle(
        font: .tkMedium(size: 44, features: .display),
        lineHeight: 56
    )

    static let num1: TKTextStyle = .init(
        font: .tkMedium(size: 32, features: .display),
        lineHeight: 40
    )

    static let h1: TKTextStyle = .init(
        font: .tkBold(size: 32, features: .display),
        lineHeight: 40
    )

    static let num2: TKTextStyle = .init(
        font: .tkMedium(size: 28, features: .display),
        lineHeight: 36
    )

    static let h2: TKTextStyle = .init(
        font: .tkBold(size: 24, features: .display),
        lineHeight: 32
    )

    static let h3: TKTextStyle = .init(
        font: .tkBold(size: 20, features: .display),
        lineHeight: 28
    )

    static let label1: TKTextStyle = .init(
        font: .tkMedium(size: 16, features: .text),
        lineHeight: 24,
        letterSpacing: 0.08
    )

    static let label2: TKTextStyle = .init(
        font: .tkMedium(size: 14, features: .text),
        lineHeight: 20,
        letterSpacing: 0.07
    )

    static let label3: TKTextStyle = .init(
        font: .tkMedium(size: 12, features: .text),
        lineHeight: 16,
        letterSpacing: 0.12
    )

    static let body1: TKTextStyle = .init(
        font: .tkRegular(size: 16, features: .text),
        lineHeight: 24,
        letterSpacing: 0.08
    )

    static let body1Mono: TKTextStyle = .init(
        font: .monospacedSystemFont(ofSize: 16, weight: .medium),
        lineHeight: 22
    )

    static let body2: TKTextStyle = .init(
        font: .tkRegular(size: 14, features: .text),
        lineHeight: 20,
        letterSpacing: 0.07
    )

    static let body3: TKTextStyle = .init(
        font: .tkRegular(size: 12, features: .text),
        lineHeight: 16,
        letterSpacing: 0.12
    )

    static let body3Alternate: TKTextStyle = .init(
        font: .tkRegular(size: 13, features: .text),
        lineHeight: 16,
        letterSpacing: 0.13
    )

    static let body4: TKTextStyle = .init(
        font: .tkMedium(size: 10, features: .text),
        lineHeight: 14,
        letterSpacing: 0.1,
        uppercased: true
    )

    static let body4Bold: TKTextStyle = .init(
        font: .tkBold(size: 10, features: .text),
        lineHeight: 14,
        letterSpacing: 0.1,
        uppercased: true
    )

    static let body4Caps: TKTextStyle = .init(
        font: .tkMedium(size: 10, features: .text),
        lineHeight: 14,
        letterSpacing: 0.1,
        uppercased: true
    )
}
