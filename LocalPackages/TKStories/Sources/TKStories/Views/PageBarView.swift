import UIKit
import TKUIKit

final class PageBarView: UIView, CAAnimationDelegate {
  
  var animationDuration: CGFloat = 0
  var progress: CGFloat {
    get {
      _progress
    }
    set {
      _progress = newValue
      updateProgress(progress, animated: false)
    }
  }
  private var _progress: CGFloat = 0
  
  private let backgroundLayer = CALayer()
  private let fillLayer = CALayer()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    backgroundLayer.frame = bounds
  }
  
  override var intrinsicContentSize: CGSize {
    CGSize(width: UIView.noIntrinsicMetric, height: .height)
  }
  
  func setProgress(_ progress: CGFloat, animated: Bool) {
    _progress = progress
    updateProgress(progress, animated: true)
  }
  
  
  func pause() {
    let pausedTime = fillLayer.convertTime(CACurrentMediaTime(), from: nil)
    fillLayer.speed = 0.0
    fillLayer.timeOffset = pausedTime
  }
  
  func resume() {
    let pausedTime = fillLayer.timeOffset
    fillLayer.speed = 1.0
    fillLayer.timeOffset = 0.0
    fillLayer.beginTime = 0.0
    let timeSincePause = fillLayer.convertTime(CACurrentMediaTime(), from: nil) - pausedTime
    fillLayer.beginTime = timeSincePause
  }
  
  private func setup() {
    backgroundLayer.backgroundColor = UIColor.Constant.white.withAlphaComponent(0.24).cgColor
    backgroundLayer.cornerRadius = .height/2
    
    fillLayer.backgroundColor = UIColor.Constant.white.cgColor
    fillLayer.anchorPoint = CGPoint(x: 0, y: 0.5)
    fillLayer.cornerRadius = .height/2
    
    layer.addSublayer(backgroundLayer)
    layer.addSublayer(fillLayer)
  }
  
  private func createFillViewFrame(bounds: CGRect, progress: CGFloat) -> CGRect {
    let frame = CGRect(origin: CGPoint(x: 0, y: 0),
                       size: CGSize(width: bounds.width * progress, height: bounds.height))
    return frame
  }
  
  private func updateProgress(_ progress: CGFloat, animated: Bool) {
    guard animated else {
      fillLayer.removeAllAnimations()
      let toFrame = createFillViewFrame(bounds: bounds, progress: progress)
      CATransaction.begin()
      CATransaction.setDisableActions(true)
      fillLayer.frame = toFrame
      CATransaction.commit()
      return
    }
    
    let fromFrame = createFillViewFrame(bounds: bounds, progress: 0)
    let toFrame = createFillViewFrame(bounds: bounds, progress: progress)
    addAnimation(fromBounds: fromFrame, toBounds: toFrame)
  }
  
  func addAnimation(fromBounds: CGRect, toBounds: CGRect) {
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    fillLayer.frame = toBounds
    CATransaction.commit()
    
    let animation = CABasicAnimation(keyPath: "bounds")
    animation.duration = animationDuration
    animation.fromValue = fromBounds
    animation.toValue = toBounds
    animation.delegate = self
    animation.isRemovedOnCompletion = false
    fillLayer.add(animation, forKey: "bounds")
  }
}

private extension CGFloat {
  static let height: CGFloat = 4
}
