import UIKit

final class TKButtonBackgroundView: UIView {
  let buttonCategory: TKButtonCategory
  let cornerRadius: CGFloat
  var state: TKButtonState = .normal {
    didSet {
      updateBackground()
    }
  }
  
  private let maskLayer = CAShapeLayer()
  
  init(buttonCategory: TKButtonCategory,
       cornerRadius: CGFloat) {
    self.buttonCategory = buttonCategory
    self.cornerRadius = cornerRadius
    super.init(frame: .zero)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
   
    maskLayer.frame = bounds
    maskLayer.path = UIBezierPath(roundedRect: bounds, cornerRadius: cornerRadius).cgPath
    layer.mask = maskLayer
  }
}

private extension TKButtonBackgroundView {
  func setup() {
    isUserInteractionEnabled = false
    updateBackground()
  }
  
  func updateBackground() {
    let backgroundColor: UIColor = {
      switch state {
      case .normal:
        return buttonCategory.backgroundColor
      case .highlighted:
        return buttonCategory.highlightedBackgroundColor
      case .disabled:
        return buttonCategory.disabledBackgroundColor
      }
    }()

    self.backgroundColor = backgroundColor
  }
}
