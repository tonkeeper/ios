import UIKit

public final class TKLoaderView: TKLayerAnimationView {
    public var isLoading = false {
        didSet {
            isLoading ? startAnimation() : stopAnimation()
        }
    }

    private let bottomCircleLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.fillColor = UIColor.clear.cgColor
        layer.lineCap = .round
        return layer
    }()

    private let topCircleLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.fillColor = UIColor.clear.cgColor
        layer.strokeStart = 0
        layer.strokeEnd = 0.25
        layer.lineCap = .round
        return layer
    }()

    private let rotationAnimation: CABasicAnimation = {
        let animation = CABasicAnimation(keyPath: "transform.rotation")
        animation.fromValue = 0.0
        animation.toValue = CGFloat(Double.pi * 2.0)
        animation.duration = 1.0
        animation.repeatCount = Float.infinity
        return animation
    }()

    public var size: Size {
        didSet {
            invalidateIntrinsicContentSize()
            didUpdateSize()
        }
    }

    public var style: Style {
        didSet { didUpdateStyle() }
    }

    public init(
        size: Size,
        style: Style
    ) {
        self.size = size
        self.style = style
        super.init(frame: .zero)
        setup()
        startAnimation()
    }

    override public var intrinsicContentSize: CGSize {
        CGSize(width: size.side, height: size.side)
    }

    override public func sizeThatFits(_ size: CGSize) -> CGSize {
        intrinsicContentSize
    }

    override public func layoutSubviews() {
        super.layoutSubviews()

        let circleRect = CGRect(
            origin: CGPoint(
                x: bounds.width / 2 - size.circleSide / 2,
                y: bounds.height / 2 - size.circleSide / 2
            ),
            size: CGSize(width: size.circleSide, height: size.circleSide)
        )
        let path = UIBezierPath(
            ovalIn: circleRect
        )

        CATransaction.begin()
        CATransaction.setValue(true, forKey: kCATransactionDisableActions)
        bottomCircleLayer.frame = bounds
        bottomCircleLayer.path = path.cgPath
        topCircleLayer.frame = bounds
        topCircleLayer.path = path.cgPath
        CATransaction.commit()
    }

    override func addAnimations() {
        topCircleLayer.add(rotationAnimation, forKey: .rotationAnimationKey)
    }

    override func removeAnimations() {
        topCircleLayer.removeAnimation(forKey: .rotationAnimationKey)
    }

    override func updateColors() {
        didUpdateStyle()
    }
}

private extension TKLoaderView {
    func setup() {
        didUpdateStyle()
        didUpdateSize()

        layer.addSublayer(bottomCircleLayer)
        layer.addSublayer(topCircleLayer)
    }

    func didUpdateSize() {
        topCircleLayer.lineWidth = size.circleWidth
        bottomCircleLayer.lineWidth = size.circleWidth
    }

    func didUpdateStyle() {
        let tintColor = style.tintColor.resolvedColor(with: traitCollection)
        bottomCircleLayer.strokeColor = tintColor.withAlphaComponent(0.32).cgColor
        topCircleLayer.strokeColor = tintColor.cgColor
    }
}

public extension TKLoaderView {
    enum Style {
        case primary
        case secondary

        var tintColor: UIColor {
            switch self {
            case .primary: return UIColor.Icon.primary
            case .secondary: return UIColor.Icon.secondary
            }
        }
    }

    enum Size {
        case xSmall
        case small
        case medium
        case large

        var side: CGFloat {
            switch self {
            case .xSmall:
                return 12
            case .small:
                return 16
            case .medium:
                return 24
            case .large:
                return 32
            }
        }

        var circleSide: CGFloat {
            switch self {
            case .xSmall:
                return 10
            case .small:
                return 14
            case .medium:
                return 20
            case .large:
                return 29.5
            }
        }

        var circleWidth: CGFloat {
            switch self {
            case .xSmall:
                return 2
            case .small:
                return 2
            case .medium:
                return 3
            case .large:
                return 2.5
            }
        }
    }
}

private extension String {
    static let rotationAnimationKey = "rotationAnimation"
}
