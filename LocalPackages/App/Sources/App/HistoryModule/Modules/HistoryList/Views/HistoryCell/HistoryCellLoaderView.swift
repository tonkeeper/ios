import TKUIKit
import UIKit

final class HistoryCellLoaderView: UIView {
    enum State: Equatable {
        case idle
        case progress(CGFloat)
        case infinite
    }

    var state: State = .idle {
        didSet {
            updateState(state, animated: true)
        }
    }

    private lazy var bottomCircleLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.fillColor = UIColor.clear.cgColor
        layer.lineCap = .round
        layer.lineWidth = Constants.lineWidth
        layer.strokeColor = UIColor.Background.contentTint.cgColor
        return layer
    }()

    private lazy var topCircleLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.fillColor = UIColor.clear.cgColor
        layer.lineCap = .round
        layer.lineWidth = Constants.lineWidth
        layer.strokeColor = UIColor.Accent.blue.cgColor
        layer.strokeStart = 0
        return layer
    }()

    override init(frame: CGRect) {
        super.init(frame: CGRect(origin: .zero, size: CGSize(width: Constants.viewSide, height: Constants.viewSide)))
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: Constants.viewSide, height: Constants.viewSide)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateCircleLayers()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        updateColors()
    }

    func updateState(_ state: State, animated: Bool = false) {
        guard self.state != state else { return }

        self.state = state

        topCircleLayer.removeAllAnimations()

        switch state {
        case .idle:
            setStrokeEnd(0, animated: animated)
        case let .progress(value):
            setStrokeEnd(min(max(value, 0), 1), animated: animated)
        case .infinite:
            setStrokeEnd(Constants.infiniteStrokeEnd, animated: animated)
            startRotationAnimation()
        }
    }

    private enum Constants {
        static let viewSide: CGFloat = 58
        static let circleSide: CGFloat = 52
        static let lineWidth: CGFloat = 3
        static let infiniteStrokeEnd: CGFloat = 0.25
    }
}

private extension HistoryCellLoaderView {
    func setup() {
        layer.addSublayer(bottomCircleLayer)
        layer.addSublayer(topCircleLayer)
        updateColors()
    }

    private func updateCircleLayers() {
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let radius = Constants.circleSide * 0.5

        let path = UIBezierPath(
            arcCenter: center,
            radius: radius,
            startAngle: -.pi * 0.5,
            endAngle: 3 * .pi * 0.5,
            clockwise: true
        )

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        for item in [bottomCircleLayer, topCircleLayer] {
            item.path = path.cgPath
            item.frame = bounds
        }

        CATransaction.commit()
    }

    func updateColors() {
        bottomCircleLayer.strokeColor = UIColor.Background.contentTint.resolvedColor(with: traitCollection).cgColor
        topCircleLayer.strokeColor = UIColor.Accent.blue.resolvedColor(with: traitCollection).cgColor
    }

    func setStrokeEnd(_ value: CGFloat, animated: Bool) {
        if animated {
            let animation = CABasicAnimation(keyPath: "strokeEnd")
            animation.fromValue = topCircleLayer.presentation()?.strokeEnd
            animation.toValue = value
            animation.duration = 0.3
            animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            topCircleLayer.add(animation, forKey: "strokeAnimation")
        }
        topCircleLayer.strokeEnd = value
    }

    func startRotationAnimation() {
        let animation = CABasicAnimation(keyPath: "transform.rotation")
        animation.fromValue = 0
        animation.toValue = CGFloat.pi * 2
        animation.duration = 1
        animation.repeatCount = .infinity
        animation.isRemovedOnCompletion = false
        topCircleLayer.add(animation, forKey: "rotationAnimation")
    }
}
