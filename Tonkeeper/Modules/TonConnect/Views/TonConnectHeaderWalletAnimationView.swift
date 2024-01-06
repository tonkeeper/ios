//
//  TonConnectHeaderWalletAnimationView.swift
//  Tonkeeper
//
//  Created by Grigory Serebryanyy on 01.11.2023.
//

import UIKit
import TKUIKitLegacy

final class TonConnectHeaderWalletAnimationView: UIView, ConfigurableView {
  
  private let addressContainer = UIView()
  private lazy var addressLabelOne = createLabel()
  private lazy var addressLabelTwo = createLabel()
  
  private let starsContainer = UIView()
  private lazy var starsLabelOne = createLabel()
  private lazy var starsLabelTwo = createLabel()
  
  private let separatorView: UIView = {
    let view = UIView()
    view.backgroundColor = .Background.contentTint
    return view
  }()
  
  private let leftGradientLayer: CAGradientLayer = {
    let layer = CAGradientLayer()
    layer.colors = [UIColor.clear.cgColor,
                    UIColor.white.cgColor]
    layer.startPoint = CGPoint(x: 0, y: 0.5)
    layer.endPoint = CGPoint(x: 1, y: 0.5)
    return layer
  }()
  
  private let rightGradientLayer: CAGradientLayer = {
    let layer = CAGradientLayer()
    layer.colors = [UIColor.white.cgColor,
                    UIColor.clear.cgColor]
    layer.startPoint = CGPoint(x: 0, y: 0.5)
    layer.endPoint = CGPoint(x: 1, y: 0.5)
    return layer
  }()
  
  private var animators = [UIViewPropertyAnimator]()
  
  // MARK: - Init
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  // MARK: - Layout
  
  override func layoutSubviews() {
    super.layoutSubviews()
    addressContainer.frame = .init(
      origin: .init(x: 0, y: 0),
      size: .init(width: bounds.width/2, height: bounds.height)
    )
    starsContainer.frame = .init(
      origin: .init(x: bounds.width/2, y: 0),
      size: .init(width: bounds.width/2, height: bounds.height)
    )
    separatorView.frame = .init(origin: .init(x: bounds.width/2 - .separatorWidth/2, y: bounds.height/2 - .separatorHeigth/2),
                                size: .init(width: .separatorWidth, height: .separatorHeigth))
    
    leftGradientLayer.frame = addressContainer.bounds
    rightGradientLayer.frame = starsContainer.bounds
    
    startAnimation()
  }
  
  // MARK: - ConfigurableView
  
  struct Model {
    let walletAddress: String
  }
  
  func configure(model: Model) {
    addressLabelOne.text = model.walletAddress
    addressLabelTwo.text = model.walletAddress
    let starsString = String(repeating: "*\u{2009}", count: model.walletAddress.count)
    starsLabelOne.text = starsString
    starsLabelTwo.text = starsString
  }
  
  // MARK: - Animation
  
  func startAnimation() {
    animators.forEach { $0.stopAnimation(true) }
    animators.removeAll()
    animateAddressLabels()
    animateStarsLabels()
  }
  
  override func didMoveToWindow() {
    super.didMoveToWindow()
    guard window != nil else { stopAppStateObservation(); return }
    startAppStateObservation()
  }
}

private extension TonConnectHeaderWalletAnimationView {
  func setup() {
    backgroundColor = .Background.page
    addressContainer.layer.masksToBounds = true
    starsContainer.layer.masksToBounds = true
    
    addSubview(addressContainer)
    addSubview(starsContainer)
    addressContainer.addSubview(addressLabelOne)
    addressContainer.addSubview(addressLabelTwo)
    starsContainer.addSubview(starsLabelOne)
    starsContainer.addSubview(starsLabelTwo)
    addSubview(separatorView)
    
    addressContainer.layer.mask = leftGradientLayer
    starsContainer.layer.mask = rightGradientLayer
  }
  
  func createLabel() -> UILabel {
    let label = UILabel()
    label.numberOfLines = 1
    label.applyTextStyleFont(.body2)
    label.textColor = .Text.tertiary
    return label
  }

  func animateAddressLabels() {
    addressLabelOne.sizeToFit()
    addressLabelTwo.sizeToFit()
    addressLabelOne.frame.origin.y = addressContainer.bounds.height/2 - addressLabelOne.frame.height/2
    addressLabelTwo.frame.origin.y = addressContainer.bounds.height/2 - addressLabelTwo.frame.height/2
    animateFirstLabel(label: addressLabelOne, container: addressContainer)
    animateSecondLabel(label: addressLabelTwo, container: addressContainer)
  }
  
  func animateStarsLabels() {
    starsLabelOne.sizeToFit()
    starsLabelTwo.sizeToFit()
    starsLabelOne.frame.origin.y = starsContainer.bounds.height/2 - starsLabelOne.frame.height/2 + 3
    starsLabelTwo.frame.origin.y = starsContainer.bounds.height/2 - starsLabelTwo.frame.height/2 + 3
    animateFirstLabel(label: starsLabelOne, container: starsContainer)
    animateSecondLabel(label: starsLabelTwo, container: starsContainer)
  }
  
  func animateFirstLabel(label: UILabel, container: UIView) {
    label.frame.origin.x = -label.bounds.width + container.bounds.width
    let animator = UIViewPropertyAnimator(duration: .animationDuration, curve: .linear, animations: {
      label.frame.origin.x = container.bounds.width
    })
    animator.startAnimation()
    animator.addCompletion { [weak self] _ in
      self?.animateSecondLabel(label: label, container: container)
    }
    animators.append(animator)
  }
  
  func animateSecondLabel(label: UILabel, container: UIView) {
    label.frame.origin.x = (-label.bounds.width * 2) + container.bounds.width
    let animator = UIViewPropertyAnimator(duration: .animationDuration * 2, curve: .linear, animations: {
      label.frame.origin.x = container.bounds.width
    })
    animator.startAnimation()
    animator.addCompletion { [weak self] _ in
      self?.animateSecondLabel(label: label, container: container)
    }
    animators.append(animator)
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
    startAnimation()
  }
}

private extension CGFloat {
  static let imageCornerRadius: CGFloat = 20
  static let separatorWidth: CGFloat = 2
  static let separatorHeigth: CGFloat = 32
}

private extension TimeInterval {
  static let animationDuration: TimeInterval = 12
}

