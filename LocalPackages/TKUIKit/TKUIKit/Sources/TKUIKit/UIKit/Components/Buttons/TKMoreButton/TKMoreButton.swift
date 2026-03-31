import UIKit

public final class TKMoreButton: UIControl {
    public static var textStyle: TKTextStyle {
        .body2
    }

    public struct Configuration {
        let title: NSAttributedString?
        let backgroundColor: UIColor
        let gradientLocations: [NSNumber]
        let gradientColors: [CGColor]

        public init(
            title: String? = nil,
            backgroundColor: UIColor = .Background.content,
            gradientLocations: [NSNumber] = [0, 0.35, 1],
            gradientColors: [CGColor] = [UIColor.clear.cgColor, UIColor.black.cgColor, UIColor.black.cgColor]
        ) {
            self.title = title?.withTextStyle(
                TKMoreButton.textStyle,
                color: .Text.accent,
                alignment: .left,
                lineBreakMode: .byTruncatingTail
            )
            self.backgroundColor = backgroundColor
            self.gradientLocations = gradientLocations
            self.gradientColors = gradientColors
        }
    }

    override public var isHighlighted: Bool {
        didSet {
            label.alpha = isHighlighted ? 0.48 : 1
        }
    }

    private let label = UILabel()
    private let backgroundView = UIView()
    private let gradientLayer = CAGradientLayer()

    public var configuration = Configuration() {
        didSet {
            updateConfiguration()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear

        backgroundView.isUserInteractionEnabled = false

        updateConfiguration()

        backgroundView.backgroundColor = configuration.backgroundColor
        backgroundView.layer.mask = gradientLayer

        addSubview(backgroundView)
        addSubview(label)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func updateConfiguration() {
        label.attributedText = configuration.title
        backgroundView.backgroundColor = configuration.backgroundColor

        gradientLayer.colors = configuration.gradientColors
        gradientLayer.locations = configuration.gradientLocations
        gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
        setNeedsLayout()
    }

    override public var intrinsicContentSize: CGSize {
        let labelIntrinsicContentSize = label.intrinsicContentSize
        return CGSize(
            width: labelIntrinsicContentSize.width + .horizontalInset,
            height: labelIntrinsicContentSize.height + .verticalInset
        )
    }

    override public func layoutSubviews() {
        super.layoutSubviews()

        backgroundView.frame = CGRect(x: 0, y: bounds.height - 20, width: bounds.width + 5, height: 20)
        gradientLayer.frame = backgroundView.bounds

        label.sizeToFit()
        label.frame.origin = CGPoint(x: bounds.width - label.bounds.width, y: bounds.height - label.bounds.height)
    }

    override public func sizeThatFits(_ size: CGSize) -> CGSize {
        var fittingSize = label.sizeThatFits(size)
        fittingSize.width += .horizontalInset
        fittingSize.height += .verticalInset
        return fittingSize
    }
}

private extension CGFloat {
    static let horizontalInset: CGFloat = 24
    static let verticalInset: CGFloat = 20
}
