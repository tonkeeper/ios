import UIKit

public enum TKGradientDirection {
    case topToBottom
    case bottomToTop
    case leftToRight
    case rightToLeft
}

public class TKGradientView: UIView {
    public var color: UIColor {
        didSet {
            self.backgroundColor = color
            self.gradientLayer.setTKGradient(color: color, direction: direction)
        }
    }

    public var direction: TKGradientDirection {
        didSet {
            self.gradientLayer.setTKGradient(color: color, direction: direction)
        }
    }

    private let gradientLayer = CAGradientLayer()

    public init(color: UIColor, direction: TKGradientDirection) {
        self.color = color
        self.direction = direction
        super.init(frame: .zero)
        self.backgroundColor = color
        self.layer.mask = gradientLayer
        gradientLayer.setTKGradient(color: color, direction: direction)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
    }
}

public extension CAGradientLayer {
    func setTKGradient(color: UIColor, direction: TKGradientDirection) {
        let colors = CAGradientLayer.gradientValues.map { color.withAlphaComponent($0).cgColor }
        let locations = CAGradientLayer.gradientValues

        let start: CGPoint
        let end: CGPoint
        switch direction {
        case .topToBottom:
            start = CGPoint(x: 0.5, y: 1)
            end = CGPoint(x: 0.5, y: 0)
        case .bottomToTop:
            start = CGPoint(x: 0.5, y: 0)
            end = CGPoint(x: 0.5, y: 1)
        case .leftToRight:
            start = CGPoint(x: 1, y: 0.5)
            end = CGPoint(x: 0, y: 0.5)
        case .rightToLeft:
            start = CGPoint(x: 0, y: 0.5)
            end = CGPoint(x: 1, y: 0.5)
        }

        self.colors = colors
        self.locations = locations as [NSNumber]
        self.startPoint = start
        self.endPoint = end
    }
}

private extension CAGradientLayer {
    static var gradientValues = [0, 0.0086, 0.03, 0.08, 0.14, 0.23, 0.33, 0.44, 0.55, 0.66, 0.76, 0.85, 0.91, 0.96, 0.99, 1]
}
