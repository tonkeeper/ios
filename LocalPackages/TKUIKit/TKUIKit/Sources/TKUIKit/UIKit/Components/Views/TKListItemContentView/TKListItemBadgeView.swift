import UIKit

public final class TKListItemBadgeView: UIView {
    public struct Configuration: Hashable {
        public enum Item: Hashable {
            case image(TKImage)
        }

        public enum Size: Hashable {
            case small
            case medium
            case large
            case xlarge

            var side: CGFloat {
                switch self {
                case .small: 18
                case .medium: 20
                case .large: 24
                case .xlarge: 32
                }
            }

            var padding: CGFloat {
                switch self {
                case .small: 2
                case .medium: 2
                case .large: 3
                case .xlarge: 4
                }
            }
        }

        public let item: Item
        public let size: Size
        public let tintColor: UIColor?
        public let backgroundColor: UIColor

        public init(
            item: Item,
            size: Size,
            tintColor: UIColor? = nil,
            backgroundColor: UIColor = .Background.content
        ) {
            self.item = item
            self.size = size
            self.tintColor = tintColor
            self.backgroundColor = backgroundColor
        }

        public static var `default`: Configuration {
            Configuration(item: .image(.image(nil)), size: .small)
        }
    }

    public var configuration = Configuration.default {
        didSet {
            didUpdateConfiguration()
            setNeedsLayout()
            invalidateIntrinsicContentSize()
        }
    }

    public let iconView = TKImageView()
    public let customViewContainer = UIView()

    private var customView: UIView?

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

        let contentViewFrame = CGRect(
            origin: CGPoint(x: configuration.size.padding, y: configuration.size.padding),
            size: CGSize(width: configuration.size.side, height: configuration.size.side)
        )
        iconView.frame = contentViewFrame
        customViewContainer.frame = contentViewFrame
        customView?.frame = customViewContainer.bounds

        layer.cornerRadius = bounds.width / 2
    }

    override public func sizeThatFits(_ size: CGSize) -> CGSize {
        CGSize(
            width: configuration.size.side + configuration.size.padding * 2,
            height: configuration.size.side + configuration.size.padding * 2
        )
    }

    private func setup() {
        backgroundColor = .Background.content

        addSubview(iconView)
        addSubview(customViewContainer)

        layer.masksToBounds = true

        didUpdateConfiguration()
    }

    private func didUpdateConfiguration() {
        backgroundColor = configuration.backgroundColor
        switch configuration.item {
        case let .image(image):
            iconView.isHidden = false
            iconView.configure(
                model: TKImageView.Model(
                    image: image,
                    tintColor: configuration.tintColor,
                    size: .size(CGSize(width: configuration.size.side, height: configuration.size.side)),
                    corners: .circle
                )
            )
            customViewContainer.isHidden = true
            customView?.removeFromSuperview()
        }
    }
}
