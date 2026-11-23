import SwiftUI
import UIKit

struct CircularLoaderLayer: UIViewRepresentable {
    let timing: CircularLoaderLayerView.Timing
    let configuration: CircularLoaderConfiguration

    func makeUIView(context: Context) -> CircularLoaderLayerView {
        CircularLoaderLayerView()
    }

    func updateUIView(_ view: CircularLoaderLayerView, context: Context) {
        view.update(
            timing: timing,
            spinner: CircularLoaderLayerView.Spinner(
                arcLength: configuration.spinnerArcLength,
                turnDuration: configuration.spinnerTurnDuration
            ),
            lineWidth: configuration.lineWidth,
            progressColor: UIColor(configuration.progressColor),
            trackColor: UIColor(configuration.trackColor)
        )
    }
}

final class CircularLoaderLayerView: TKLayerAnimationView {
    struct Timing: Equatable {
        let mode: CircularLoaderMode
        let duration: TimeInterval
        let startDate: Date
    }

    struct Spinner: Equatable {
        let arcLength: CGFloat
        let turnDuration: TimeInterval
    }

    let progressLayer = CAShapeLayer()
    private let trackLayer = CAShapeLayer()
    private var timing: Timing?
    private var spinner = Spinner(arcLength: 0, turnDuration: 1)
    private var progressColor = UIColor.clear
    private var trackColor = UIColor.clear

    init() {
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        for shapeLayer in [trackLayer, progressLayer] {
            shapeLayer.fillColor = nil
            shapeLayer.lineCap = .round
            layer.addSublayer(shapeLayer)
        }
        startAnimation()
    }

    func update(timing: Timing, spinner: Spinner, lineWidth: CGFloat, progressColor: UIColor, trackColor: UIColor) {
        self.progressColor = progressColor
        self.trackColor = trackColor
        withoutImplicitAnimations {
            trackLayer.lineWidth = lineWidth
            progressLayer.lineWidth = lineWidth
        }
        updateColors()
        guard timing != self.timing || spinner != self.spinner else { return }
        self.timing = timing
        self.spinner = spinner
        restartAnimations()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let path = UIBezierPath(
            arcCenter: CGPoint(x: bounds.midX, y: bounds.midY),
            radius: min(bounds.width, bounds.height) / 2,
            startAngle: -.pi / 2,
            endAngle: .pi * 3 / 2,
            clockwise: true
        ).cgPath
        withoutImplicitAnimations {
            for shapeLayer in [trackLayer, progressLayer] {
                shapeLayer.frame = bounds
                shapeLayer.path = path
            }
        }
    }

    override func updateColors() {
        withoutImplicitAnimations {
            progressLayer.strokeColor = progressColor.resolvedColor(with: traitCollection).cgColor
            trackLayer.strokeColor = trackColor.resolvedColor(with: traitCollection).cgColor
        }
    }

    override func addAnimations() {
        guard let timing else { return }
        let now = Date()
        switch timing.mode {
        case .determinate:
            withoutImplicitAnimations {
                progressLayer.strokeEnd = 1
            }
            if let animation = Self.countdownAnimation(
                timing: timing,
                now: now,
                mediaTime: progressLayer.convertTime(CACurrentMediaTime(), from: nil)
            ) {
                progressLayer.add(animation, forKey: .progressAnimationKey)
            }
        case .indeterminate:
            withoutImplicitAnimations {
                progressLayer.strokeEnd = spinner.arcLength
            }
            progressLayer.add(
                Self.spinnerAnimation(at: now, turnDuration: spinner.turnDuration),
                forKey: .progressAnimationKey
            )
        }
    }

    override func removeAnimations() {
        progressLayer.removeAnimation(forKey: .progressAnimationKey)
    }
}

extension CircularLoaderLayerView {
    /// The ring fills from where the countdown stands now to full in the time left; nil once it has run out.
    static func countdownAnimation(timing: Timing, now: Date, mediaTime: CFTimeInterval) -> CABasicAnimation? {
        let elapsed = now.timeIntervalSince(timing.startDate)
        guard timing.duration > 0, elapsed < timing.duration else { return nil }
        let animation = CABasicAnimation(keyPath: "strokeEnd")
        animation.fromValue = max(elapsed, 0) / timing.duration
        animation.toValue = 1.0
        animation.duration = timing.duration - max(elapsed, 0)
        animation.timingFunction = CAMediaTimingFunction(name: .linear)
        if elapsed < 0 {
            animation.beginTime = mediaTime - elapsed
            animation.fillMode = .backwards
        }
        // A countdown moves a fraction of a point per frame: a lower rate looks the same and costs less.
        animation.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 120, preferred: 60)
        return animation
    }

    /// Spinners stay in step with each other: the turn is derived from the wall clock.
    static func spinnerAnimation(at date: Date, turnDuration: TimeInterval) -> CABasicAnimation {
        let phase = date.timeIntervalSinceReferenceDate
            .truncatingRemainder(dividingBy: turnDuration) / turnDuration
        let startAngle = phase * 2 * .pi
        let animation = CABasicAnimation(keyPath: "transform.rotation.z")
        animation.fromValue = startAngle
        animation.toValue = startAngle + 2 * .pi
        animation.duration = turnDuration
        animation.repeatCount = .infinity
        animation.timingFunction = CAMediaTimingFunction(name: .linear)
        animation.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)
        return animation
    }
}

private func withoutImplicitAnimations(_ changes: () -> Void) {
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    changes()
    CATransaction.commit()
}

private extension String {
    static let progressAnimationKey = "progress"
}
