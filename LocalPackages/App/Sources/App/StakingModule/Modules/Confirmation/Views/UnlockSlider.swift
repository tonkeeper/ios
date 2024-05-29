import UIKit
import TKUIKit
import SnapKit

final class UnlockSlider: UIControl {
  enum Position {
    case start
    case end
  }
  
  var didUnlock: (() -> Void)?
  var title: NSAttributedString? {
    didSet {
      label.attributedText = title
    }
  }
  
  private let containerView = UIView()
  private let imageView: UIImageView = {
    let view = UIImageView()
    view.contentMode = .center
    view.image = .TKUIKit.Icons.Size28.arrowRightOutline
    view.tintColor = .Text.primary
    view.isUserInteractionEnabled = true
    return view
  }()
  private let trailView: UIView = {
    let view = UIView()
    view.backgroundColor = .Background.page
    view.layer.cornerRadius = .cornerRadius
    
    return view
  }()
  private let pitchView: UIView = {
    let view = UIView()
    view.backgroundColor = .Button.primaryBackground
    view.layer.cornerRadius = .cornerRadius
    view.clipsToBounds = true
    view.layer.masksToBounds = true
    return view
  }()
  private let label = UILabel()
  private var leadingImageViewConstraint: Constraint?
  
  private var position: Position = .start
  private var gradientLayer = CAGradientLayer()
  
  private var xEnd: CGFloat {
    self.containerView.frame.maxX - imageView.bounds.width
  }
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func willMove(toWindow newWindow: UIWindow?) {
    super.willMove(toWindow: newWindow)
    if newWindow != nil {
      startGradientAnimation()
    } else {
      gradientLayer.removeAllAnimations()
    }
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    
    label.sizeToFit()
    gradientLayer.frame = label.bounds
    startGradientAnimation()
  }
  
  func resetToStartPosition(animated: Bool = false) {
    position = .start
    updatePitch(position: .xStart, animated: animated)
  }
}

// MARK: - Private methods

private extension UnlockSlider {
  func setup() {
    backgroundColor = .Background.content
    layer.cornerRadius = .cornerRadius
    
    addPanGesture()
    setupConstraints()
    setupGradientLayer()
    startGradientAnimation()
    
    layoutIfNeeded()
  }
  
  func setupConstraints() {
    containerView.fill(in: self)
    
    label.layout(in: containerView) {
      $0.center.equalToSuperview()
    }
    
    containerView.addSubview(trailView)
    trailView.addSubview(pitchView)
    
    trailView.snp.makeConstraints {
      $0.leading.top.bottom.equalToSuperview()
      $0.trailing.equalTo(pitchView.snp.trailing)
    }
    
    pitchView.snp.makeConstraints {
      leadingImageViewConstraint = $0.leading.equalTo(containerView.snp.leading).constraint
      $0.centerY.equalTo(containerView.snp.centerY)
      $0.height.equalToSuperview()
      $0.width.equalTo(CGFloat.buttonWidth)
    }
    
    imageView.fill(in: pitchView)
  }
  
  @objc
  func handleGesture(_ sender: UIPanGestureRecognizer) {
    let translatedPoint = sender.translation(in: containerView).x
    switch sender.state {
    case .changed:
      gestureDidChange(translatedPoint: translatedPoint)
    case .ended:
      gestureDidEnd(translatedPoint: translatedPoint)
    default:
      break
    }
  }
  
  func gestureDidChange(translatedPoint: CGFloat) {
    if translatedPoint > .zero {
      guard position == .start else {
        if translatedPoint >= xEnd {
          updatePitch(position: xEnd)
        }
        return
      }
      if translatedPoint >= xEnd {
        updatePitch(position: xEnd)
        return
      }
      updatePitch(position: translatedPoint)
    }
  }
  
  func gestureDidEnd(translatedPoint: CGFloat) {
    if translatedPoint > .zero {
      guard position == .start else { return }
      if translatedPoint > .xStart && translatedPoint < xEnd {
        updatePitch(position: .xStart, animated: true)
        position = .start
      } else if translatedPoint >= xEnd {
        updatePitch(position: xEnd, animated: true)
        position = .end
        didUnlock?()
      }
    }
  }
  
  func addPanGesture() {
    let panGestureRecognizer = UIPanGestureRecognizer(
      target: self,
      action: #selector(self.handleGesture(_:))
    )
    panGestureRecognizer.minimumNumberOfTouches = 1
    imageView.addGestureRecognizer(panGestureRecognizer)
  }
  
  private func setupGradientLayer() {
    gradientLayer.colors = [
      UIColor(red: 194/255, green: 218/255, blue: 255/255, alpha: 0.4).cgColor,
      UIColor(red: 194/255, green: 218/255, blue: 255/255, alpha: 1).cgColor,
      UIColor(red: 194/255, green: 218/255, blue: 255/255, alpha: 0.4).cgColor
    ]
    gradientLayer.locations = [0.0, 0.5, 1.0]
    gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
    gradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
    label.layer.mask = gradientLayer
  }
  
  func startGradientAnimation() {
    gradientLayer.removeAllAnimations()
    
    let gradientAnimation = CABasicAnimation(keyPath: "locations")
    gradientAnimation.fromValue = [-1, -0.5, 0]
    gradientAnimation.toValue = [1, 1.5, 2]
    gradientAnimation.duration = 1.5
    gradientAnimation.repeatCount = .infinity
    gradientAnimation.timingFunction = CAMediaTimingFunction(name: .linear)
    
    gradientLayer.add(gradientAnimation, forKey: "gradientAnimation")
  }
  
  func updatePitch(position: CGFloat, animated: Bool = false) {
    if animated {
      UIView.animate(withDuration: 0.2, delay: .zero, options: .curveEaseOut) { [weak self] in
        guard let self else { return  }
        self.leadingImageViewConstraint?.update(offset: position)
        self.layoutIfNeeded()
      }
    } else {
      leadingImageViewConstraint?.update(offset: position)
      layoutIfNeeded()
    }
  }
}

private extension CGFloat {
  static let cornerRadius: Self = 16
  static let buttonWidth: Self = 92
  
  static let xStart: CGFloat = .zero
}
