//
//  ShimmerView.swift
//  Tonkeeper
//
//  Created by Grigory on 27.7.23..
//

import UIKit

final class ShimmerView: UIView {
  private let gradientLayer = CAGradientLayer()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
    subscribeNotifications()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  deinit {
    unsubscribeNotifications()
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    gradientLayer.frame = bounds
  }
  
  func startAnimation() {
    let animation = CABasicAnimation(keyPath: .animationKeyPath)
    animation.isRemovedOnCompletion = false
    animation.fromValue = [-1.0, -0.5, 0.0]
    animation.toValue = [1.0, 1.5, 2.0]
    animation.repeatCount = .infinity
    animation.duration = 0.9
    gradientLayer.add(animation, forKey: animation.keyPath)
  }
  
  func stopAnimation() {
    gradientLayer.removeAnimation(forKey: .animationKeyPath)
  }
}

private extension ShimmerView {
  func setup() {
    gradientLayer.startPoint = .init(x: 0, y: 1)
    gradientLayer.endPoint = .init(x: 1, y: 1)
    gradientLayer.colors = [
      CGColor.gradientMainColor,
      CGColor.gradientHighlightColor,
      CGColor.gradientMainColor
    ]
    gradientLayer.locations = [0.0, 0.5, 1.0]
    layer.addSublayer(gradientLayer)
  }
  
  func subscribeNotifications() {
    NotificationCenter.default
      .addObserver(self,
                   selector: #selector(appWillResignActive),
                   name: UIApplication.willResignActiveNotification,
                   object: nil)
    
    NotificationCenter.default
      .addObserver(self,
                   selector: #selector(appDidBecomeActive),
                   name: UIApplication.didBecomeActiveNotification,
                   object: nil)
  }
  
  func unsubscribeNotifications() {
    NotificationCenter.default.removeObserver(
      self,
      name: UIApplication.willResignActiveNotification,
      object: nil
    )
    
    NotificationCenter.default.removeObserver(
      self,
      name: UIApplication.didBecomeActiveNotification,
      object: nil
    )
  }
  
  @objc
  func appWillResignActive() {
    stopAnimation()
  }
  
  @objc
  func appDidBecomeActive() {
    startAnimation()
  }
}

private extension String {
  static let animationKeyPath = "locations"
}

private extension CGColor {
  static var gradientMainColor: CGColor { UIColor.Background.contentTint.cgColor }
  static var gradientHighlightColor: CGColor { UIColor.Background.contentAttention.cgColor }
}
