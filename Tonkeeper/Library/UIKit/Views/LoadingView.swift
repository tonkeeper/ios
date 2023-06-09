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
      case .xSmall: return 8.5
      case .small: return 14
      case .medium: return 20
      case .large: return 30
      case .xLarge: return 60
      }
    }
    
    var lineWidth: CGFloat {
      switch self {
      case .xSmall,
          .small,
          .medium,
          .large: return 1.5
      case .xLarge: return 3
      }
    }
  }
  
  var size: Size {
    didSet { didChangeSize() }
  }
  
  var color: UIColor = .Icon.primary {
    didSet { circleLayer.strokeColor = color.cgColor }
  }
  
  private lazy var circleLayer: CAShapeLayer = {
    let layer = CAShapeLayer()
    layer.fillColor = UIColor.clear.cgColor
    layer.strokeColor = color.cgColor
    layer.strokeEnd = 0.75
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
    circleLayer.frame = bounds
    circleLayer.path = path.cgPath
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
    circleLayer.add(rotateAnimation(), forKey: .rotateAnimationKey)
  }
  
  func stopAnimation() {
    isAnimating = false
    circleLayer.removeAnimation(forKey: .rotateAnimationKey)
  }
}

private extension LoaderView {
  func setup() {
    layer.addSublayer(circleLayer)
    didChangeSize()
  }
  
  func didChangeSize() {
    invalidateIntrinsicContentSize()
    circleLayer.lineWidth = size.lineWidth
  }
  
  func rotateAnimation() -> CAAnimation {
    let animation = CABasicAnimation(keyPath: .rotateAnimationKey)
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

