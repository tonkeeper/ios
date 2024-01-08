import UIKit
import TKUIKit

final class PasscodeDotView: UIView {
  
  enum State {
    case empty
    case filled
    case success
    case failed
    
    var backgroundColor: UIColor {
      switch self {
      case .empty: return .Background.content
      case .filled: return .Accent.blue
      case .success: return .Accent.green
      case .failed: return .Accent.red
      }
    }
  }
  
  var state: State = .empty {
    didSet {
      guard state != oldValue else { return }
      updateStateAppearance()
    }
  }
  
  private var scaleAnimation: CABasicAnimation = {
    let animation = CABasicAnimation(keyPath: "transform.scale")
    animation.fromValue = 1
    animation.toValue = 1.5
    animation.duration = 0.1
    animation.autoreverses = true
    return animation
  }()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  // MARK: - Layout
  
  override var intrinsicContentSize: CGSize {
    let side: CGFloat
    switch state {
    case .failed:
      side = .bigSide
    default:
      side = .side
    }
    return .init(width: side, height: side)
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    layer.cornerRadius = bounds.height / 2
  }
}

private extension PasscodeDotView {
  func setup() {
    updateStateAppearance()
  }
  
  func updateStateAppearance() {
    backgroundColor = state.backgroundColor
    switch state {
    case .filled, .success:
      layer.add(scaleAnimation, forKey: "scaleAnimation")
    case .empty, .failed:
      layer.removeAnimation(forKey: "scaleAnimation")
    }
  }
}

private extension CGFloat {
  static let side: CGFloat = 12
  static let bigSide: CGFloat = 16
}
