import UIKit

public final class TKShimmerLabel: UIView {
    public var text: NSAttributedString? {
        didSet {
            label.attributedText = text
        }
    }

    public let label: UILabel = {
        let label = UILabel()
        label.numberOfLines = 2
        return label
    }()

    let gradientLayer: CAGradientLayer = {
        let layer = CAGradientLayer()
        layer.startPoint = CGPoint(x: 0, y: 0.5)
        layer.endPoint = CGPoint(x: 1, y: 0.5)
        layer.colors = [UIColor.clear.cgColor, UIColor.white.cgColor, UIColor.clear.cgColor]
        layer.locations = [0.2, 0.5, 0.8]
        return layer
    }()

    lazy var contentLayer: CALayer = {
        let layer = CALayer()
        layer.backgroundColor = UIColor.Text.tertiary.cgColor
        layer.anchorPoint = .zero
        layer.mask = label.layer
        return layer
    }()

    lazy var shimmerLayer: CAGradientLayer = {
        let layer = CAGradientLayer()
        layer.colors = [UIColor(hex: "C2DAFF", alpha: 1).cgColor, UIColor.white.cgColor]
        layer.anchorPoint = .zero
        layer.startPoint = CGPoint(x: 0, y: 0.5)
        layer.endPoint = CGPoint(x: 1, y: 0.5)
        layer.mask = gradientLayer
        return layer
    }()

    private var enterForegroundToken: NSObjectProtocol?

    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(label)

        layer.addSublayer(contentLayer)
        contentLayer.addSublayer(shimmerLayer)

        addAnimation()

        enterForegroundToken = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.addAnimation()
        }
    }

    deinit {
        enterForegroundToken = nil
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func layoutSubviews() {
        super.layoutSubviews()
        label.frame = bounds
        contentLayer.frame = bounds
        shimmerLayer.frame = bounds
        gradientLayer.frame = bounds
    }

    public func startAnimation() {
        addAnimation()
    }

    public func stopAnimation() {
        gradientLayer.removeAllAnimations()
    }

    private func addAnimation() {
        let gradientAnimation = CABasicAnimation(keyPath: "locations")
        gradientAnimation.fromValue = [0.0, 0.0, 0.25]
        gradientAnimation.toValue = [0.75, 1.0, 1.0]
        gradientAnimation.duration = 2.0
        gradientAnimation.repeatCount = Float.infinity

        gradientLayer.add(gradientAnimation, forKey: nil)
    }
}
