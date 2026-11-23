import SwiftUI
import UIKit

/// Scrolls one line of text sideways forever at a fixed pace. The render server moves it, so no frame costs
/// the main thread and it runs at the screen's full rate.
public struct TKTicker: UIViewRepresentable {
    let text: String
    let textStyle: TKTextStyle
    let color: TKColor
    let pointsPerSecond: CGFloat

    public init(text: String, textStyle: TKTextStyle, color: TKColor, pointsPerSecond: CGFloat) {
        self.text = text
        self.textStyle = textStyle
        self.color = color
        self.pointsPerSecond = pointsPerSecond
    }

    public func makeUIView(context: Context) -> TKTickerView {
        let view = TKTickerView()
        view.startAnimation()
        return view
    }

    public func updateUIView(_ view: TKTickerView, context: Context) {
        view.update(
            text: text.withTextStyle(
                textStyle,
                color: UIColor(color.resolve(context.environment.tkPalette)),
                lineBreakMode: .byClipping
            ),
            pointsPerSecond: pointsPerSecond
        )
    }
}

/// Two copies of the text run back to back, and the strip moves by one copy's width per loop, so the loop
/// has no seam.
public final class TKTickerView: TKLayerAnimationView {
    private let strip = UIView()
    private let labels = [UILabel(), UILabel()]
    private var text: NSAttributedString?
    private var pointsPerSecond: CGFloat = 0
    private var textWidth: CGFloat = 0

    override public init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = true
        addSubview(strip)
        labels.forEach { strip.addSubview($0) }
    }

    func update(text: NSAttributedString, pointsPerSecond: CGFloat) {
        if text != self.text {
            self.text = text
            labels.forEach { $0.attributedText = text }
            invalidateIntrinsicContentSize()
            setNeedsLayout()
        }
        // A new width restarts the loop from layoutSubviews, so a color change keeps the ticker's place.
        if pointsPerSecond != self.pointsPerSecond {
            self.pointsPerSecond = pointsPerSecond
            restartAnimations()
        }
    }

    override public var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: labels[0].intrinsicContentSize.height)
    }

    override public func layoutSubviews() {
        super.layoutSubviews()
        let size = labels[0].intrinsicContentSize
        for (index, label) in labels.enumerated() {
            label.frame = CGRect(
                x: CGFloat(index) * size.width,
                y: (bounds.height - size.height) / 2,
                width: size.width,
                height: size.height
            )
        }
        strip.frame = CGRect(x: 0, y: 0, width: size.width * 2, height: bounds.height)
        if size.width != textWidth {
            textWidth = size.width
            restartAnimations()
        }
    }

    override func addAnimations() {
        guard let animation = Self.tickerAnimation(textWidth: textWidth, pointsPerSecond: pointsPerSecond) else { return }
        strip.layer.add(animation, forKey: Self.animationKey)
    }

    override func removeAnimations() {
        strip.layer.removeAnimation(forKey: Self.animationKey)
    }

    static let animationKey = "ticker"

    /// Moves the strip right from the second copy's start to the first's, then starts over.
    static func tickerAnimation(textWidth: CGFloat, pointsPerSecond: CGFloat) -> CABasicAnimation? {
        guard textWidth > 0, pointsPerSecond > 0 else { return nil }
        let animation = CABasicAnimation(keyPath: "transform.translation.x")
        animation.fromValue = -textWidth
        animation.toValue = 0
        animation.duration = textWidth / pointsPerSecond
        animation.repeatCount = .infinity
        return animation
    }
}
