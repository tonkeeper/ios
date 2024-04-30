import UIKit

public final class TKSpacingView: UIView {
  
  public enum Spacing {
    case none
    case constant(CGFloat)
  }
  
  var horizontalSpacing: Spacing {
    didSet { invalidateIntrinsicContentSize() }
  }
  var verticalSpacing: Spacing {
    didSet { invalidateIntrinsicContentSize() }
  }
  
  public init(horizontalSpacing: Spacing = .none,
              verticalSpacing: Spacing = .none) {
    self.horizontalSpacing = horizontalSpacing
    self.verticalSpacing = verticalSpacing
    super.init(frame: .zero)
    setup()
  }
  
  public required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public override var intrinsicContentSize: CGSize {
    let width: CGFloat
    switch horizontalSpacing {
    case .none:
      width = UIView.noIntrinsicMetric
    case let .constant(value):
      width = value
    }
    
    let height: CGFloat
    switch verticalSpacing {
    case .none:
      height = UIView.noIntrinsicMetric
    case let .constant(value):
      height = value
    }
    
    return CGSize(width: width, height: height)
  }
}

private extension TKSpacingView {
  func setup() {
    backgroundColor = .clear
  }
}
