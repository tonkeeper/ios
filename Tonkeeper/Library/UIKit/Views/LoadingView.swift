//
//  LoadingView.swift
//  Tonkeeper
//
//  Created by Grigory on 5.6.23..
//

import UIKit

final class LoaderView: UIView {
  
  enum Size {
    case xSmall
    case small
    case medium
    case large
    case xLarge
    
    var side: CGFloat {
      switch self {
      case .xSmall: return 10
      case .small: return 14
      case .medium: return 20
      case .large: return 30
      case .xLarge: return 60
      }
    }
    
    var lineWidth: CGFloat {
      switch self {
      case .xSmall, .small: return 1.5
      case .xLarge, .medium, .large: return 3
      }
    }
  }
  
  var size: Size {
    didSet { didChangeSize() }
  }
  
  var color: UIColor = .Icon.primary {
    didSet { upperCircleLayer.strokeColor = color.cgColor }
  }
  
  var innerColor: UIColor = .clear {
    didSet { innerCircleLayer.strokeColor = innerColor.cgColor }
  }
  
  private lazy var upperCircleLayer: CAShapeLayer = {
    let layer = CAShapeLayer()
    layer.fillColor = UIColor.clear.cgColor
    layer.strokeColor = color.cgColor
    layer.strokeStart = 0
    layer.strokeEnd = 0.25
    return layer
  }()
  
  private lazy var innerCircleLayer: CAShapeLayer = {
    let layer = CAShapeLayer()
    layer.fillColor = UIColor.clear.cgColor
    layer.strokeColor = innerColor.cgColor
    layer.strokeStart = 0.25
    layer.strokeEnd = 1
    return layer
  }()
  
  private var isAnimating: Bool = false
  
  init(size: Size) {
    self.size = size
    super.init(frame: .zero)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    
    let pathBounds = CGRect(x: bounds.width/2 - size.side/2,
                            y: bounds.height/2 - size.side/2,
                            width: size.side,
                            height: size.side)
    let path = UIBezierPath(ovalIn: pathBounds)
    
    CATransaction.begin()
    CATransaction.setValue(true, forKey: kCATransactionDisableActions)
    upperCircleLayer.frame = bounds
    upperCircleLayer.path = path.cgPath
    innerCircleLayer.frame = bounds
    innerCircleLayer.path = path.cgPath
    CATransaction.commit()
  }
  
  override var intrinsicContentSize: CGSize {
    .init(width: size.side, height: size.side)
  }
  
  override func didMoveToWindow() {
    super.didMoveToWindow()
    guard window != nil else { stopAppStateObservation(); return }
    startAppStateObservation()
  }
  
  func startAnimation() {
    isAnimating = true
    upperCircleLayer.add(rotateAnimation(), forKey: .rotateAnimationKey)
    innerCircleLayer.add(rotateAnimation(), forKey: .rotateAnimationKey)
  }
  
  func stopAnimation() {
    isAnimating = false
    upperCircleLayer.removeAnimation(forKey: .rotateAnimationKey)
    innerCircleLayer.removeAnimation(forKey: .rotateAnimationKey)
  }
}

private extension LoaderView {
  func setup() {
    layer.addSublayer(upperCircleLayer)
    layer.addSublayer(innerCircleLayer)
    didChangeSize()
  }
  
  func didChangeSize() {
    invalidateIntrinsicContentSize()
    upperCircleLayer.lineWidth = size.lineWidth
    innerCircleLayer.lineWidth = size.lineWidth
  }
  
  func rotateAnimation() -> CAAnimation {
    let animation = CABasicAnimation(keyPath: .rotateAnimationKey)
    animation.isRemovedOnCompletion = false
    animation.fromValue = 0.0
    animation.toValue = CGFloat(Double.pi * 2.0)
    animation.duration = 1.0
    animation.repeatCount = Float.infinity
    return animation
  }
  
  func startAppStateObservation() {
    NotificationCenter.default.addObserver(self,
                                           selector: #selector(willEnterForeground),
                                           name: UIApplication.willEnterForegroundNotification,
                                           object: nil)
  }
  
  func stopAppStateObservation() {
    NotificationCenter.default.removeObserver(self,
                                              name: UIApplication.willEnterForegroundNotification,
                                              object: nil)
  }
  
  @objc
  func willEnterForeground() {
    guard isAnimating else { return }
    startAnimation()
  }
}

private extension String {
  static let rotateAnimationKey = "transform.rotation"
}

