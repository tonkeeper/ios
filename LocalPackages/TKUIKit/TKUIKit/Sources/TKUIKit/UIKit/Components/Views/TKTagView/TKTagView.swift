import UIKit

public final class TKTagView: UIView {
    public struct Configuration: Hashable {
        public var text: NSAttributedString
        public var textPadding: UIEdgeInsets
        public var backgroundColor: UIColor
        public var borderColor: UIColor
        public var backgroundPadding: UIEdgeInsets

        public init(
            text: String,
            textColor: UIColor,
            textPadding: UIEdgeInsets,
            backgroundColor: UIColor,
            borderColor: UIColor,
            backgroundPadding: UIEdgeInsets
        ) {
            self.text = text.uppercased().withTextStyle(
                .body4,
                color: textColor,
                alignment: .center,
                lineBreakMode: .byTruncatingTail
            )
            self.textPadding = textPadding
            self.backgroundColor = backgroundColor
            self.borderColor = borderColor
            self.backgroundPadding = backgroundPadding
        }

        public static func accentTag(
            text: String,
            color: UIColor
        ) -> Configuration {
            Configuration(
                text: text,
                textColor: color,
                textPadding: UIEdgeInsets(top: 2.5, left: 5, bottom: 3.5, right: 5),
                backgroundColor: color.withAlphaComponent(0.16),
                borderColor: .clear,
                backgroundPadding: UIEdgeInsets(top: 0, left: 6, bottom: 0, right: 0)
            )
        }

        public static func tag(text: String) -> Configuration {
            Configuration(
                text: text,
                textColor: .Text.secondary,
                textPadding: UIEdgeInsets(top: 2.5, left: 5, bottom: 3.5, right: 5),
                backgroundColor: .Background.contentTint,
                borderColor: .clear,
                backgroundPadding: UIEdgeInsets(top: 0, left: 6, bottom: 0, right: 0)
            )
        }

        public static func outlintTag(text: String) -> Configuration {
            Configuration(
                text: text,
                textColor: .Text.secondary,
                textPadding: UIEdgeInsets(top: 2.5, left: 5, bottom: 3.5, right: 5),
                backgroundColor: .clear,
                borderColor: .Background.contentTint,
                backgroundPadding: UIEdgeInsets(top: 0, left: 6, bottom: 0, right: 0)
            )
        }
    }

    public var configuration: Configuration = .outlintTag(text: "Tag") {
        didSet {
            didUpdateConfiguration()
            setNeedsLayout()
            invalidateIntrinsicContentSize()
        }
    }

    private let textLabel = UILabel()
    private let backgroundLayer = CAShapeLayer()

    override public init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func layoutSubviews() {
        super.layoutSubviews()

        let backgroundFrame = bounds.inset(by: configuration.backgroundPadding)
        let textFrame = backgroundFrame.inset(by: configuration.textPadding)

        backgroundLayer.frame = backgroundFrame
        backgroundLayer.path = UIBezierPath(roundedRect: backgroundLayer.bounds, cornerRadius: .cornerRadius).cgPath
        textLabel.frame = textFrame
    }

    override public func sizeThatFits(_ size: CGSize) -> CGSize {
        let textWidth = size.width
            - configuration.backgroundPadding.left
            - configuration.backgroundPadding.right
            - configuration.textPadding.left
            - configuration.textPadding.right
        let textSizeThatFits = textLabel.sizeThatFits(CGSize(width: textWidth, height: 0))
        let textResultWidth = min(textWidth, textSizeThatFits.width)
        let width = textResultWidth
            + configuration.backgroundPadding.left
            + configuration.backgroundPadding.right
            + configuration.textPadding.left
            + configuration.textPadding.right
        let height = textSizeThatFits.height
            + configuration.backgroundPadding.top
            + configuration.backgroundPadding.bottom
            + configuration.textPadding.top
            + configuration.textPadding.bottom
        return CGSize(width: width, height: height)
    }

    override public var intrinsicContentSize: CGSize {
        sizeThatFits(CGSize(width: CGFloat.infinity, height: 0))
    }

    private func setup() {
        layer.addSublayer(backgroundLayer)
        addSubview(textLabel)

        didUpdateConfiguration()
    }

    private func didUpdateConfiguration() {
        textLabel.attributedText = configuration.text
        backgroundLayer.fillColor = configuration.backgroundColor.cgColor
        backgroundLayer.strokeColor = configuration.borderColor.cgColor
    }
}

private extension CGFloat {
    static let cornerRadius: CGFloat = 4
}
