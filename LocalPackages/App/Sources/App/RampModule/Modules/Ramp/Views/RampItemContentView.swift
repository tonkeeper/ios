import TKUIKit
import UIKit

final class RampItemContentView: UIView {
    struct Configuration: Hashable {
        var iconViewConfiguration: TKListItemIconView.Configuration
        var titleViewConfiguration: TKListItemTitleView.Configuration
        var captionViewConfiguration: RampItemCaptionWithIconsView.Configuration

        static var `default`: Configuration {
            Configuration(
                iconViewConfiguration: .init(content: .image(.init(image: nil)), alignment: .center, size: .zero),
                titleViewConfiguration: TKListItemTitleView.Configuration(title: ""),
                captionViewConfiguration: .init(text: "", iconURLs: [])
            )
        }
    }

    var configuration = Configuration.default {
        didSet {
            didUpdateConfiguration()
            setNeedsLayout()
            invalidateIntrinsicContentSize()
        }
    }

    private let iconView = TKListItemIconView()
    private let titleView = TKListItemTitleView()
    private let captionWithIconsView = RampItemCaptionWithIconsView()

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

        let iconViewSize = iconView.sizeThatFits(.zero)
        let iconViewSpace = iconViewSize.width + Constants.spacing
        let rightWidth = bounds.width - iconViewSpace

        iconView.frame = CGRect(
            origin: CGPoint(x: 0, y: 0),
            size: CGSize(width: iconViewSize.width, height: bounds.height)
        )

        let titleSize = titleView.sizeThatFits(CGSize(width: rightWidth, height: 0))
        titleView.frame = CGRect(
            origin: CGPoint(x: iconViewSpace, y: 0),
            size: CGSize(width: rightWidth, height: titleSize.height)
        )

        let captionHeight = captionWithIconsView.sizeThatFits(CGSize(width: rightWidth, height: 0)).height
        captionWithIconsView.frame = CGRect(
            origin: CGPoint(x: iconViewSpace, y: titleSize.height),
            size: CGSize(width: rightWidth, height: captionHeight)
        )
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let iconViewSize = iconView.sizeThatFits(.zero)
        let iconViewSpace = iconViewSize.width + Constants.spacing
        let rightWidth = size.width - iconViewSpace

        let titleHeight = titleView.sizeThatFits(CGSize(width: rightWidth, height: 0)).height
        let captionHeight = captionWithIconsView.sizeThatFits(CGSize(width: rightWidth, height: .greatestFiniteMagnitude)).height

        return CGSize(width: size.width, height: titleHeight + captionHeight)
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: sizeThatFits(CGSize(width: bounds.width, height: 0)).height)
    }

    func prepareForReuse() {
        iconView.prepareForReuse()
        captionWithIconsView.prepareForReuse()
    }

    private func setup() {
        addSubview(iconView)
        addSubview(titleView)
        addSubview(captionWithIconsView)
    }

    private func didUpdateConfiguration() {
        titleView.configuration = configuration.titleViewConfiguration
        iconView.configuration = configuration.iconViewConfiguration
        captionWithIconsView.configure(model: configuration.captionViewConfiguration)
    }
}

private extension RampItemContentView {
    enum Constants {
        static let spacing: CGFloat = 16
    }
}
