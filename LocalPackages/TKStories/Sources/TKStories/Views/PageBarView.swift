import UIKit
import TKUIKit

final class PageBarView: UIView, CAAnimationDelegate {
  
  var progress: CGFloat {
    get {
      _progress
    }
    set {
      _progress = newValue
      updateProgress(progress, animationDuration: 0)
    }
  }
  private var _progress: CGFloat = 0
  
  private let backgroundLayer = CAShapeLayer()
  private let fillLayer = CAShapeLayer()
  
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
    fillLayer.frame = bounds
    fillLayer.lineWidth = bounds.height
    
    backgroundLayer.path = UIBezierPath(roundedRect: bounds, cornerRadius: 2).cgPath
    fillLayer.path = createFillLayerPath(bounds: bounds).cgPath
  }
  
  override var intrinsicContentSize: CGSize {
    CGSize(width: UIView.noIntrinsicMetric, height: .height)
  }
  
  func setProgress(_ progress: CGFloat, animationDuration: TimeInterval) {
    _progress = progress
    updateProgress(progress, animationDuration: animationDuration)
  }
  
  func pause() {
    let pauseTime = fillLayer.convertTime(CACurrentMediaTime(), from: nil)
    fillLayer.speed = 0
    fillLayer.timeOffset = pauseTime
  }
  
  func resume() {
    let pausedTime = fillLayer.timeOffset
    fillLayer.speed = 1
    fillLayer.timeOffset = 0
    fillLayer.beginTime = 0
    let timeSincePause = fillLayer.convertTime(CACurrentMediaTime(), from: nil) - pausedTime
    fillLayer.beginTime = timeSincePause
  }
  
  private func setup() {
    backgroundLayer.fillColor = UIColor.Constant.white.withAlphaComponent(0.24).cgColor
    backgroundLayer.cornerRadius = 2
    backgroundLayer.masksToBounds = true
    
    fillLayer.strokeColor = UIColor.Constant.white.cgColor
    fillLayer.strokeEnd = progress
    
    layer.addSublayer(backgroundLayer)
    backgroundLayer.addSublayer(fillLayer)
  }
  
  private func createFillLayerPath(bounds: CGRect) -> UIBezierPath {
    let path = UIBezierPath()
    path.move(to: CGPoint(x: 0, y: bounds.height/2))
    path.addLine(to: CGPoint(x: bounds.width, y: bounds.height/2))
    return path
  }
  
  private func updateProgress(_ progress: CGFloat, animationDuration: TimeInterval) {
    let fromValue: CGFloat = 0
    guard !animationDuration.isZero else {
      fillLayer.removeAllAnimations()
      CATransaction.begin()
      CATransaction.setDisableActions(true)
      fillLayer.strokeEnd = _progress
      CATransaction.commit()
      return
    }
    let duration = abs(progress - fromValue) * animationDuration
    let animation = CABasicAnimation(keyPath: "strokeEnd")
    animation.duration = duration
    animation.fromValue = fromValue
    animation.toValue = progress
    animation.delegate = self
    fillLayer.add(animation, forKey: "strokeEnd")
  }
  
  func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
    guard flag else { return }
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    fillLayer.strokeEnd = _progress
    CATransaction.commit()
  }
}

private extension CGFloat {
  static let height: CGFloat = 4
}
