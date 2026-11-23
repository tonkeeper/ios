import UIKit

/// A pill toast's edge while its operation runs: a faint track and a beam going round it.
final class ToastProgressBorderView: TKLayerAnimationView {
    private let trackLayer = CAShapeLayer()
    private let beamClipLayer = CALayer()
    private let beamMaskLayer = CAShapeLayer()
    private let beamLayer = CAGradientLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false

        trackLayer.fillColor = nil
        trackLayer.lineWidth = .trackWidth
        layer.addSublayer(trackLayer)

        beamLayer.type = .conic
        beamLayer.startPoint = CGPoint(x: 0.5, y: 0.5)
        beamLayer.endPoint = CGPoint(x: 1, y: 0.5)
        beamLayer.locations = [0, 0.5, 0.88, 0.985, 1]
        beamMaskLayer.fillColor = nil
        beamMaskLayer.strokeColor = UIColor.black.cgColor
        beamMaskLayer.lineWidth = .beamWidth
        beamClipLayer.mask = beamMaskLayer
        beamClipLayer.addSublayer(beamLayer)
        layer.addSublayer(beamClipLayer)

        updateColors()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        trackLayer.path = pillPath(lineWidth: .trackWidth)
        beamClipLayer.frame = bounds
        beamMaskLayer.frame = bounds
        beamMaskLayer.path = pillPath(lineWidth: .beamWidth)
        let side = hypot(bounds.width, bounds.height)
        beamLayer.bounds = CGRect(x: 0, y: 0, width: side, height: side)
        beamLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
        CATransaction.commit()
    }

    /// With Reduce Motion the beam stays in place and pulses, so the toast still shows progress.
    override func addAnimations() {
        guard !UIAccessibility.isReduceMotionEnabled else {
            let pulse = CABasicAnimation(keyPath: "opacity")
            pulse.fromValue = 1
            pulse.toValue = 0.3
            pulse.duration = 1
            pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            pulse.autoreverses = true
            pulse.repeatCount = .infinity
            beamClipLayer.add(pulse, forKey: .pulseKey)
            return
        }
        let rotation = CABasicAnimation(keyPath: "transform.rotation.z")
        rotation.fromValue = 0
        rotation.toValue = CGFloat.pi * 2
        rotation.duration = 2
        rotation.timingFunction = CAMediaTimingFunction(name: .linear)
        rotation.repeatCount = .infinity
        beamLayer.add(rotation, forKey: .rotationKey)
    }

    override func removeAnimations() {
        beamLayer.removeAnimation(forKey: .rotationKey)
        beamClipLayer.removeAnimation(forKey: .pulseKey)
    }

    override func updateColors() {
        let white = UIColor.Constant.white.resolvedColor(with: traitCollection)
        trackLayer.strokeColor = white.withAlphaComponent(0.08).cgColor
        beamLayer.colors = [0, 0, 0.28, 0.85, 0].map { white.withAlphaComponent($0).cgColor }
    }

    /// A stroke of `lineWidth` along the inside of the pill's edge.
    private func pillPath(lineWidth: CGFloat) -> CGPath {
        let rect = bounds.insetBy(dx: lineWidth / 2, dy: lineWidth / 2)
        return UIBezierPath(roundedRect: rect, cornerRadius: rect.height / 2).cgPath
    }
}

private extension CGFloat {
    static let trackWidth: CGFloat = 1.5
    static let beamWidth: CGFloat = 2
}

private extension String {
    static let rotationKey = "rotation"
    static let pulseKey = "pulse"
}
