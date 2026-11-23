import UIKit

public final class TKShimmerView: TKLayerAnimationView {
    private let gradientLayer = CAGradientLayer()

    private let animation: CABasicAnimation = {
        let animation = CABasicAnimation(keyPath: .animationKeyPath)
        animation.isRemovedOnCompletion = false
        animation.fromValue = [-1.0, -0.5, 0.0]
        animation.toValue = [1.0, 1.5, 2.0]
        animation.repeatCount = .infinity
        animation.duration = 0.9
        return animation
    }()

    override public init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
        layer.cornerRadius = bounds.height / 2
    }

    override func addAnimations() {
        gradientLayer.add(animation, forKey: .animationKeyPath)
    }

    override func removeAnimations() {
        gradientLayer.removeAnimation(forKey: .animationKeyPath)
    }
}

private extension TKShimmerView {
    func setup() {
        layer.masksToBounds = true

        gradientLayer.startPoint = .init(x: 0, y: 1)
        gradientLayer.endPoint = .init(x: 1, y: 1)
        gradientLayer.colors = [
            CGColor.gradientMainColor,
            CGColor.gradientHighlightColor,
            CGColor.gradientMainColor,
        ]
        gradientLayer.locations = [0.0, 0.5, 1.0]
        layer.addSublayer(gradientLayer)
    }
}

private extension String {
    static let animationKeyPath = "locations"
}

private extension CGColor {
    static var gradientMainColor: CGColor {
        UIColor.Background.contentTint.withAlphaComponent(0.30).cgColor
    }

    static var gradientHighlightColor: CGColor {
        UIColor.Background.contentTint.withAlphaComponent(0.15).cgColor
    }
}
