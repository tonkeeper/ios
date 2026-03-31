import TKUIKit
import UIKit

public extension AccountEventCellActionView {
    final class CommentView: UIView, ReusableView {
        let textBackground: UIView = {
            let view = UIView()
            view.backgroundColor = .Bubble.background
            view.layer.cornerRadius = .cornerRadius
            return view
        }()

        let textLabel: UILabel = {
            let label = UILabel()
            label.backgroundColor = .Bubble.background
            label.numberOfLines = 0
            return label
        }()

        public struct Configuration: Hashable {
            let comment: NSAttributedString

            public init(comment: NSAttributedString) {
                self.comment = comment
            }

            public init(comment: String) {
                self.comment = comment.withTextStyle(.body2, color: .Bubble.foreground)
            }
        }

        override init(frame: CGRect) {
            super.init(frame: frame)
            setup()
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override public func layoutSubviews() {
            super.layoutSubviews()

            let textAvailableWidth = bounds.width - .textHorizontalSpacing * 2
            let textSize = textLabel.tkSizeThatFits(textAvailableWidth)

            textBackground.frame = .init(
                x: 0,
                y: .topSpace,
                width: textSize.width + .textHorizontalSpacing * 2,
                height: textSize.height + .textTopSpacing + .textBottomSpacing
            )
            textLabel.frame = .init(
                x: .textHorizontalSpacing,
                y: .textTopSpacing,
                width: textBackground.bounds.width - .textHorizontalSpacing * 2,
                height: textBackground.bounds.height - .textBottomSpacing - .textTopSpacing
            )
        }

        override public func sizeThatFits(_ size: CGSize) -> CGSize {
            guard let text = textLabel.text, !text.isEmpty else { return .zero }
            let textWidth = size.width - .textHorizontalSpacing * 2
            let textSize = textLabel.tkSizeThatFits(textWidth)
            return .init(
                width: textSize.width + .textHorizontalSpacing * 2,
                height: textSize.height + .textTopSpacing + .textBottomSpacing + .topSpace
            )
        }

        public func configure(configuration: Configuration) {
            textLabel.attributedText = configuration.comment
            setNeedsLayout()
        }

        public func prepareForReuse() {
            textLabel.attributedText = nil
        }
    }
}

private extension AccountEventCellActionView.CommentView {
    func setup() {
        addSubview(textBackground)
        textBackground.addSubview(textLabel)
    }
}

private extension CGFloat {
    static let cornerRadius: CGFloat = 12
    static let textTopSpacing: CGFloat = 7.5
    static let textBottomSpacing: CGFloat = 8.5
    static let textHorizontalSpacing: CGFloat = 12
    static let topSpace: CGFloat = 8
}
