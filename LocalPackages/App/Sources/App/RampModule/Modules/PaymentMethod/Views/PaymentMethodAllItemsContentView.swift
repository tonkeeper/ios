import TKUIKit
import UIKit

final class PaymentMethodAllItemsContentView: UIView {
    struct Configuration: Hashable {
        let leftImage: TKImage
        let rightImage: TKImage
        let title: String

        static let empty = Configuration(
            leftImage: .image(nil),
            rightImage: .image(nil),
            title: ""
        )
    }

    var configuration = Configuration.empty {
        didSet {
            didUpdateConfiguration()
            setNeedsLayout()
            invalidateIntrinsicContentSize()
        }
    }

    private let iconContainerView = UIView()
    private let leftImageView = TKOutsideBorderImageView()
    private let rightImageView = TKImageView()
    private let titleLabel = UILabel()

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

        iconContainerView.frame = CGRect(origin: .zero, size: Constants.iconContainerSize)

        let leftImageViewSize = CGSize(
            width: Constants.iconSize.width + Constants.borderWidth * 2,
            height: Constants.iconSize.height + Constants.borderWidth * 2
        )
        leftImageView.frame = CGRect(
            origin: CGPoint(
                x: -Constants.borderWidth,
                y: (Constants.iconContainerSize.height - leftImageViewSize.height) / 2
            ),
            size: leftImageViewSize
        )
        rightImageView.frame = CGRect(
            origin: CGPoint(
                x: Constants.overlap,
                y: (Constants.iconContainerSize.height - Constants.iconSize.height) / 2
            ),
            size: Constants.iconSize
        )

        let textX = Constants.iconContainerSize.width + Constants.textLeftPadding
        let textWidth = max(0, bounds.width - textX)
        let titleSize = titleLabel.sizeThatFits(CGSize(width: textWidth, height: 0))
        titleLabel.frame = CGRect(
            x: textX,
            y: bounds.midY - titleSize.height / 2,
            width: textWidth,
            height: titleSize.height
        )
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let textWidth = max(0, size.width - Constants.iconContainerSize.width - Constants.textLeftPadding)
        let titleHeight = titleLabel.sizeThatFits(CGSize(width: textWidth, height: 0)).height
        let height = max(Constants.iconContainerSize.height, titleHeight)

        return CGSize(width: size.width, height: height)
    }

    func prepareForReuse() {
        leftImageView.prepareForReuse()
        rightImageView.prepareForReuse()
    }

    private func setup() {
        addSubview(iconContainerView)
        iconContainerView.addSubview(rightImageView)
        iconContainerView.addSubview(leftImageView)
        addSubview(titleLabel)

        didUpdateConfiguration()
    }

    private func didUpdateConfiguration() {
        leftImageView.configuration = .init(
            image: configuration.leftImage,
            imageSize: Constants.iconSize,
            borderWidth: Constants.borderWidth,
            borderColor: .Background.content
        )

        rightImageView.configure(model: .init(image: configuration.rightImage, size: .size(Constants.iconSize), corners: .circle))

        titleLabel.attributedText = configuration.title.withTextStyle(
            .label1,
            color: .Text.primary,
            alignment: .left,
            lineBreakMode: .byTruncatingTail
        )
    }
}

private extension PaymentMethodAllItemsContentView {
    enum Constants {
        static let overlap: CGFloat = 10
        static let iconContainerSize: CGSize = .init(width: 28, height: 28)
        static let iconSize: CGSize = .init(width: 18, height: 18)
        static let borderWidth: CGFloat = 2
        static let textLeftPadding: CGFloat = 16
    }
}
