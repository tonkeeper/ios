import UIKit

public enum TKGradientDirection {
  case topToBottom
  case bottomToTop
  case leftToRight
  case rightToLeft
}

public class TKGradientView: UIView {
  private let gradientLayer: CAGradientLayer
  
  public init(color: UIColor, direction: TKGradientDirection) {
    self.gradientLayer = .tkLayer(color: .black, direction: direction)
    super.init(frame: .zero)
    self.backgroundColor = color
    self.layer.mask = gradientLayer
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public override func layoutSubviews() {
    super.layoutSubviews()
    gradientLayer.frame = bounds
  }
}

public extension CAGradientLayer {
  static func tkLayer(color: UIColor, direction: TKGradientDirection) -> CAGradientLayer {
    let layer = CAGradientLayer()
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
    
    layer.colors = colors
    layer.locations = locations as [NSNumber]
    layer.startPoint = start
    layer.endPoint = end
    
    return layer
  }
}

private extension CAGradientLayer {
  static var gradientValues = [0, 0.0086, 0.03, 0.08, 0.14, 0.23, 0.33, 0.44, 0.55, 0.66, 0.76, 0.85, 0.91, 0.96, 0.99, 1]
}
