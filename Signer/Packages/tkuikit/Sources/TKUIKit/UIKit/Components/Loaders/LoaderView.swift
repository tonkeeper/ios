import UIKit

final class LoaderView: UIView {
  
  private let size: Size
  private let style: Style
  
  private let bottomCircleLayer: CAShapeLayer = {
    let layer = CAShapeLayer()
    layer.fillColor = UIColor.clear.cgColor
    layer.strokeColor = UIColor.Icon.tertiary.cgColor
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
  
  private var isAnimating = false
  private var observer: NSObject?
  
  init(size: Size,
       style: Style) {
    self.size = size
    self.style = style
    super.init(frame: .zero)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override var intrinsicContentSize: CGSize {
    CGSize(width: size.side, height: size.side)
  }
  
  override func sizeThatFits(_ size: CGSize) -> CGSize {
    intrinsicContentSize
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    
    let path = UIBezierPath(
      ovalIn: bounds.insetBy(dx: size.side - size.circleSide,
                             dy: size.side - size.circleSide)
    )
  
    CATransaction.begin()
    CATransaction.setValue(true, forKey: kCATransactionDisableActions)
    bottomCircleLayer.frame = bounds
    bottomCircleLayer.path = path.cgPath
    topCircleLayer.frame = bounds
    topCircleLayer.path = path.cgPath
    CATransaction.commit()
  }
  
  override func didMoveToWindow() {
    super.didMoveToWindow()
    guard window != nil else {
      NotificationCenter.default.removeObserver(
        self,
        name: UIApplication.willEnterForegroundNotification,
        object: nil
      )
      return
    }
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(willEnterForeground),
      name: UIApplication.willEnterForegroundNotification,
      object: nil
    )
  }
  
  func startAnimation() {
    stopAnimation()
    isAnimating = true
    topCircleLayer.add(rotationAnimation, forKey: nil)
  }

  func stopAnimation() {
    isAnimating = false
    topCircleLayer.removeAllAnimations()
  }
}

private extension LoaderView {
  func setup() {
    topCircleLayer.strokeColor = style.tintColor.cgColor
    topCircleLayer.lineWidth = size.circleWidth
    bottomCircleLayer.lineWidth = size.circleWidth
    
    layer.addSublayer(bottomCircleLayer)
    layer.addSublayer(topCircleLayer)
  }

  @objc
  func willEnterForeground() {
    guard isAnimating else { return }
    startAnimation()
  }
}

extension LoaderView {
  public enum Style {
    case primary
    case secondary
    
    var tintColor: UIColor {
      switch self {
      case .primary: return UIColor.Icon.primary
      case .secondary: return UIColor.Icon.secondary
      }
    }
  }
  
  public enum Size {
    case xSmall
    case small
    case medium
    
    var side: CGFloat {
      switch self {
      case .xSmall:
        return 12
      case .small:
        return 16
      case .medium:
        return 24
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
      }
    }
  }
}
