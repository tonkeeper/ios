import UIKit

public final class TKListItemTextView: UIView, TKCollectionViewSupplementaryContainerViewContentView {
    public struct Configuration: Hashable {
        public let text: NSAttributedString?
        public let numberOfLines: Int
        public let padding: UIEdgeInsets

        public init(
            text: String? = nil,
            color: UIColor,
            textStyle: TKTextStyle,
            alignment: NSTextAlignment = .left,
            lineBreakMode: NSLineBreakMode = .byTruncatingTail,
            numberOfLines: Int = 1,
            padding: UIEdgeInsets = .zero
        ) {
            self.text = text?.withTextStyle(
                textStyle,
                color: color,
                alignment: alignment,
                lineBreakMode: lineBreakMode
            )
            self.numberOfLines = numberOfLines
            self.padding = padding
        }

        public init(
            text: NSAttributedString?,
            numberOfLines: Int = 1,
            padding: UIEdgeInsets = .zero
        ) {
            self.text = text
            self.numberOfLines = numberOfLines
            self.padding = padding
        }
    }

    public var configuration = Configuration(text: "Label", color: .Text.primary, textStyle: .body2) {
        didSet {
            didUpdateConfiguration()
            setNeedsLayout()
            invalidateIntrinsicContentSize()
        }
    }

    let textLabel = UILabel()

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

        let labelFrame = CGRect(
            x: configuration.padding.left,
            y: configuration.padding.top,
            width: bounds.width - configuration.padding.left - configuration.padding.right,
            height: bounds.height - configuration.padding.top - configuration.padding.bottom
        )
        textLabel.frame = labelFrame
    }

    override public func sizeThatFits(_ size: CGSize) -> CGSize {
        let width = size.width - configuration.padding.left - configuration.padding.right
        let labelSizeThatFits = textLabel.sizeThatFits(CGSize(width: width, height: .zero))
        guard labelSizeThatFits != .zero else {
            return .zero
        }
        let labelWidth = min(labelSizeThatFits.width, size.width)
        let resultWidth = labelWidth + configuration.padding.left + configuration.padding.right
        let resultHeight = labelSizeThatFits.height + configuration.padding.top + configuration.padding.bottom
        return CGSize(width: resultWidth, height: resultHeight)
    }

    override public var intrinsicContentSize: CGSize {
        sizeThatFits(CGSize(width: CGFloat.infinity, height: 0))
    }

    private func setup() {
        addSubview(textLabel)

        didUpdateConfiguration()
    }

    private func didUpdateConfiguration() {
        textLabel.attributedText = configuration.text
        textLabel.numberOfLines = configuration.numberOfLines
    }

    public func prepareForReuse() {
        textLabel.text = nil
    }

    public func configure(model: Configuration) {
        configuration = model
    }
}

extension UIEdgeInsets: @retroactive Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.left)
        hasher.combine(self.bottom)
        hasher.combine(self.right)
        hasher.combine(self.top)
    }
}
