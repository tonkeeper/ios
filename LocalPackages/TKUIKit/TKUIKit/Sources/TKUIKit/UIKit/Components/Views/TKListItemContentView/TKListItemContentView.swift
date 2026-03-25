import UIKit

public final class TKListItemContentView: UIView {
    public struct Configuration: Hashable {
        public let iconViewConfiguration: TKListItemIconView.Configuration?
        public let textContentViewConfiguration: TKListItemTextContentView.Configuration

        public static var `default`: Configuration {
            Configuration(textContentViewConfiguration: .default)
        }

        public init(
            iconViewConfiguration: TKListItemIconView.Configuration? = nil,
            textContentViewConfiguration: TKListItemTextContentView.Configuration
        ) {
            self.iconViewConfiguration = iconViewConfiguration
            self.textContentViewConfiguration = textContentViewConfiguration
        }
    }

    public var configuration = Configuration.default {
        didSet {
            didUpdateConfiguration()
            setNeedsLayout()
            invalidateIntrinsicContentSize()
        }
    }

    public let iconView = TKListItemIconView()
    public let textContentView = TKListItemTextContentView()

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

        let iconViewSize: CGSize = {
            guard !iconView.isHidden else {
                return .zero
            }
            return iconView.sizeThatFits(.zero)
        }()
        let iconViewFrame = CGRect(
            origin: CGPoint(x: 0, y: 0),
            size: CGSize(width: iconViewSize.width, height: bounds.height)
        )

        let iconViewSpace: CGFloat = iconView.isHidden ? 0 : iconViewSize.width + 16

        let textContentViewSize: CGSize = {
            let width: CGFloat = bounds.width - iconViewSpace
            return textContentView.sizeThatFits(CGSize(width: width, height: 0))
        }()
        let textContentFrame = CGRect(
            origin: CGPoint(x: iconViewSpace, y: 0),
            size: CGSize(width: textContentViewSize.width, height: bounds.height)
        )
        textContentView.frame = textContentFrame
        iconView.frame = iconViewFrame
    }

    override public func sizeThatFits(_ size: CGSize) -> CGSize {
        super.sizeThatFits(size)

        let iconViewSize: CGSize = {
            guard !iconView.isHidden else {
                return .zero
            }
            return iconView.sizeThatFits(.zero)
        }()

        let textContentViewSize: CGSize = {
            let width: CGFloat = iconViewSize.width == 0 ? size.width : size.width - 16 - iconViewSize.width
            return textContentView.sizeThatFits(CGSize(width: width, height: 0))
        }()

        let height = max(iconViewSize.height, textContentViewSize.height)
        return CGSize(width: size.width, height: height)
    }

    override public var intrinsicContentSize: CGSize {
        return CGSize(width: UIView.noIntrinsicMetric, height: sizeThatFits(.init(width: bounds.width, height: 0)).height)
    }

    public func prepareForReuse() {
        iconView.prepareForReuse()
    }

    private func setup() {
        addSubview(iconView)
        addSubview(textContentView)
    }

    private func didUpdateConfiguration() {
        textContentView.configuration = configuration.textContentViewConfiguration

        if let iconViewConfiguration = configuration.iconViewConfiguration {
            iconView.isHidden = false
            iconView.configuration = iconViewConfiguration
        } else {
            iconView.isHidden = true
            iconView.configuration = TKListItemIconView.Configuration.default
        }
    }
}
