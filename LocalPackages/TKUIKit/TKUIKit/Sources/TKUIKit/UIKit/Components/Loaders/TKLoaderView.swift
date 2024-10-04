import UIKit

public final class TKLoaderView: UIView {
  
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
  
  private var isAnimating = false
  private var observer: NSObject?
  
  public var size: Size {
    didSet {
      invalidateIntrinsicContentSize()
      didUpdateSize()
    }
  }
  public var style: Style {
    didSet { didUpdateStyle() }
  }
  
  public init(size: Size,
              style: Style) {
    self.size = size
    self.style = style
    super.init(frame: .zero)
    setup()
    
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(willEnterForeground),
      name: UIApplication.willEnterForegroundNotification,
      object: nil
    )
    
    if #available(iOS 17.0, *) {
      registerForTraitChanges([UITraitUserInterfaceStyle.self]) { [weak self] (traitEnvironment: Self, previousTraitCollection: UITraitCollection) in
        self?.bottomCircleLayer.strokeColor = style.tintColor.withAlphaComponent(0.32).cgColor
        self?.topCircleLayer.strokeColor = style.tintColor.cgColor
      }
    }
  }
  
  deinit {
    NotificationCenter.default.removeObserver(
      self,
      name: UIApplication.willEnterForegroundNotification,
      object: nil
    )
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public override var intrinsicContentSize: CGSize {
    CGSize(width: size.side, height: size.side)
  }
  
  public override func sizeThatFits(_ size: CGSize) -> CGSize {
    intrinsicContentSize
  }
  
  public override func layoutSubviews() {
    super.layoutSubviews()
    
    let circleRect = CGRect(
      origin: CGPoint(
        x: bounds.width/2 - size.circleSide/2,
        y: bounds.height/2 - size.circleSide/2
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

  public override func didMoveToWindow() {
    super.didMoveToWindow()
    if window == nil {
      stopAnimation()
    } else {
      startAnimation()
    }
  }
  
  public func startAnimation() {
    isAnimating = true
    topCircleLayer.removeAnimation(forKey: .rotationAnimationKey)
    topCircleLayer.add(rotationAnimation, forKey: .rotationAnimationKey)
  }

  public func stopAnimation() {
    isAnimating = false
    topCircleLayer.removeAnimation(forKey: .rotationAnimationKey)
  }

  public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    super.traitCollectionDidChange(previousTraitCollection)
    if #unavailable(iOS 17.0) {
      bottomCircleLayer.strokeColor = style.tintColor.withAlphaComponent(0.32).cgColor
      topCircleLayer.strokeColor = style.tintColor.cgColor
    }
  }
}

private extension TKLoaderView {
  func setup() {
    didUpdateStyle()
    didUpdateSize()
    
    layer.addSublayer(bottomCircleLayer)
    layer.addSublayer(topCircleLayer)
  }

  @objc
  func willEnterForeground() {
    guard isAnimating else { return }
    startAnimation()
  }
  
  func didUpdateSize() {
    topCircleLayer.lineWidth = size.circleWidth
    bottomCircleLayer.lineWidth = size.circleWidth
  }
  
  func didUpdateStyle() {
    bottomCircleLayer.strokeColor = style.tintColor.withAlphaComponent(0.32).cgColor
    topCircleLayer.strokeColor = style.tintColor.cgColor
  }
}

extension TKLoaderView {
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

private extension String {
  static let rotationAnimationKey = "rotationAnimation"
}
