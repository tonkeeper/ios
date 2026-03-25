import TKLocalize
import TKUIKit
import UIKit

extension HistoryCellActionView {
    final class CommentView: UIView, ReusableView {
        let textBackground: UIView = {
            let view = UIView()
            view.backgroundColor = .Background.contentTint
            view.layer.cornerRadius = .cornerRadius
            return view
        }()

        let textLabel: UILabel = {
            let label = UILabel()
            label.backgroundColor = .Background.contentTint
            label.numberOfLines = 0
            return label
        }()

        let moreButton: TKMoreButton = {
            let button = TKMoreButton()
            button.configuration = TKMoreButton.Configuration(
                title: TKLocales.History.Event.Comment.more,
                backgroundColor: .moreButtonBackgroundColor,
                gradientLocations: .moreButtonGradientLocations,
                gradientColors: .moreButtonGradientColors
            )
            return button
        }()

        struct Configuration: Hashable {
            let comment: NSAttributedString

            init(comment: NSAttributedString) {
                self.comment = comment
            }

            init(comment: String) {
                self.comment = comment.withTextStyle(.body2, color: .Text.primary)
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

        override func layoutSubviews() {
            super.layoutSubviews()

            let textAvailableWidth = bounds.width - .textHorizontalSpacing * 2
            let textSize = textLabel.tkSizeThatFits(textAvailableWidth)
            let textHeight = min(textSize.height, maxTextHeight)

            textBackground.frame = .init(
                x: 0,
                y: .topSpace,
                width: textSize.width + .textHorizontalSpacing * 2,
                height: textHeight + .textTopSpacing + .textBottomSpacing
            )
            textLabel.frame = .init(
                x: .textHorizontalSpacing,
                y: .textTopSpacing,
                width: textBackground.bounds.width - .textHorizontalSpacing * 2,
                height: textBackground.bounds.height - .textBottomSpacing - .textTopSpacing
            )
            let moreButtonSize = moreButton.sizeThatFits(bounds.size)
            moreButton.frame = .init(
                x: textLabel.frame.maxX - moreButtonSize.width,
                y: textLabel.frame.maxY - moreButtonSize.height,
                width: moreButtonSize.width,
                height: moreButtonSize.height
            )

            configureMoreButtonVisibility()
        }

        override func sizeThatFits(_ size: CGSize) -> CGSize {
            guard let text = textLabel.text, !text.isEmpty else { return .zero }
            let textWidth = size.width - .textHorizontalSpacing * 2
            let textSize = textLabel.tkSizeThatFits(textWidth)
            let textHeight = min(textSize.height, maxTextHeight) + .textTopSpacing + .textBottomSpacing + .topSpace
            return .init(
                width: textSize.width + .textHorizontalSpacing * 2,
                height: textHeight
            )
        }

        func configure(configuration: Configuration) {
            textLabel.attributedText = configuration.comment
            setNeedsLayout()
        }

        func prepareForReuse() {
            textLabel.attributedText = nil
        }

        private var maxTextHeight: CGFloat {
            .maxLines * TKMoreButton.textStyle.lineHeight
        }

        private func configureMoreButtonVisibility() {
            let labelContentHeight = textLabel.heightThatFits(.greatestFiniteMagnitude)
            moreButton.isHidden = labelContentHeight <= maxTextHeight
        }
    }
}

private extension HistoryCellActionView.CommentView {
    func setup() {
        addSubview(textBackground)
        textBackground.addSubview(textLabel)
        textBackground.addSubview(moreButton)
    }
}

private extension CGFloat {
    static let cornerRadius: CGFloat = 12
    static let textTopSpacing: CGFloat = 7.5
    static let textBottomSpacing: CGFloat = 8.5
    static let textHorizontalSpacing: CGFloat = 12
    static let topSpace: CGFloat = 8
    static let maxLines: CGFloat = 2
}

private extension UIColor {
    static var moreButtonBackgroundColor: UIColor {
        .Background.contentTint
    }
}

private extension Array where Element == NSNumber {
    static var moreButtonGradientLocations: [NSNumber] {
        [0, 0.2, 1]
    }
}

private extension Array where Element == CGColor {
    static var moreButtonGradientColors: [CGColor] {
        [
            UIColor.clear.cgColor,
            UIColor.moreButtonBackgroundColor.cgColor,
            UIColor.moreButtonBackgroundColor.cgColor,
        ]
    }
}
