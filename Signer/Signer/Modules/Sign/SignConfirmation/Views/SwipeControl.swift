import UIKit
import SnapKit
import SignerLocalize

final class SwipeControl: UIView {
  
  var didConfirm: (() -> Void)?
  
  let contentView = UIView()
  let backgroundView = UIView()
  let dragView = UIView()
  let shimmerCoverView = UIView()
  let imageView = UIImageView()
  let gradientLabel = ShimmerLabel()
  
  private var isLocked = false {
    didSet {
      guard isLocked != oldValue else { return }
      let image: UIImage
      if isLocked {
        image = .TKUIKit.Icons.Size28.donemarkOutline
        UINotificationFeedbackGenerator().notificationOccurred(.success)
      } else {
        image = .TKUIKit.Icons.Size28.arrowRightOutline
      }
      UIView.transition(with: imageView, duration: 0.2, options: .transitionCrossDissolve) {
        self.imageView.image = image
      }
    }
  }
  
  private var dragViewLeftConstraint: Constraint?
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  func reset() {
    isLocked = false
    dragViewLeftConstraint?.update(offset: 0)
    gradientLabel.alpha = 1
  }
}

private extension SwipeControl {
  func setup() {
    backgroundColor = .clear
    
    contentView.backgroundColor = .clear
    
    backgroundView.backgroundColor = .Background.content
    backgroundView.layer.cornerRadius = 16
    backgroundView.layer.cornerCurve = .continuous
    
    shimmerCoverView.backgroundColor = .Background.content
    shimmerCoverView.layer.cornerRadius = 16
    shimmerCoverView.layer.cornerCurve = .continuous
    
    dragView.backgroundColor = .Button.primaryBackground
    dragView.layer.cornerRadius = 16
    dragView.layer.cornerCurve = .continuous
    
    imageView.image = .TKUIKit.Icons.Size28.arrowRightOutline
    imageView.tintColor = .Button.primaryForeground
    imageView.contentMode = .center
    
    addSubview(contentView)
    contentView.addSubview(backgroundView)
    contentView.addSubview(shimmerCoverView)
    contentView.addSubview(dragView)
    backgroundView.addSubview(gradientLabel)
    
    dragView.addSubview(imageView)
    
    let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(panGestureHandler(_:)))
    dragView.addGestureRecognizer(panGestureRecognizer)
    
    setupConstraints()
    
    gradientLabel.text = SignerLocalize.SignTransaction.slide_to_sign
  }
  
  func setupConstraints() {
    contentView.snp.makeConstraints { make in
      make.height.equalTo(CGFloat.height)
      make.top.bottom.equalTo(self).inset(CGFloat.padding)
      make.left.right.equalTo(self)
    }
    
    backgroundView.snp.makeConstraints { make in
      make.edges.equalTo(contentView)
    }
    
    dragView.snp.makeConstraints { make in
      make.height.equalTo(CGFloat.height)
      make.width.equalTo(CGFloat.dragViewWidth)
      make.centerY.equalTo(backgroundView)
      dragViewLeftConstraint = make.left.equalTo(backgroundView).constraint
    }
    
    shimmerCoverView.snp.makeConstraints { make in
      make.top.left.bottom.equalTo(contentView)
      make.right.equalTo(dragView)
    }
    
    imageView.snp.makeConstraints { make in
      make.edges.equalTo(dragView)
    }
    
    gradientLabel.snp.makeConstraints { make in
      make.width.height.equalTo(backgroundView)
      make.centerX.centerY.equalTo(backgroundView)
    }
  }
  
  @objc
  func panGestureHandler(_ gestureRecognizer: UIPanGestureRecognizer) {
    switch gestureRecognizer.state {
    case .changed:
      let translation = gestureRecognizer.translation(in: gestureRecognizer.view)
      let minOffset: CGFloat = 0
      let maxOffset = backgroundView.bounds.width - dragView.frame.width
      let offset = max(min(maxOffset, translation.x), minOffset)
      let progress = offset / (maxOffset - dragView.frame.width)
      gradientLabel.alpha = 1 - progress
      isLocked = offset == maxOffset
      dragViewLeftConstraint?.update(offset: offset)
    case .ended:
      if isLocked {
        didConfirm?()
      } else {
        resetDragViewPosition()
      }
    case .cancelled:
      resetDragViewPosition()
    default: break
    }
  }
  
  func resetDragViewPosition() {
    UINotificationFeedbackGenerator().notificationOccurred(.error)
    dragViewLeftConstraint?.update(offset: 0)
    UIView.animate(
      withDuration: 0.4,
      delay: 0,
      usingSpringWithDamping: 0.7,
      initialSpringVelocity: 1,
      options: [.allowUserInteraction]) {
        self.gradientLabel.alpha = 1
        self.contentView.layoutIfNeeded()
      }

  }
}

private extension CGFloat {
  static let height: CGFloat = 56
  static let padding: CGFloat = 16
  static let dragViewWidth: CGFloat = 76
}
