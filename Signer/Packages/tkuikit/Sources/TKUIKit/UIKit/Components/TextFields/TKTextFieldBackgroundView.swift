import UIKit

final class TKTextFieldBackgroundView: UIView {
  var state: TKTextInputContainerState = .inactive {
    didSet {
      updateBackground()
      updateBorder()
    }
  }
  
  override init(frame: CGRect) {
    super.init(frame: .zero)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

private extension TKTextFieldBackgroundView {
  func setup() {
    layer.cornerRadius = .cornerRadius
    layer.borderWidth = .borderWidth
    updateBackground()
    updateBorder()
  }
  
  func updateBackground() {
    backgroundColor = state.backgroundColor
  }
  
  func updateBorder() {
    layer.borderColor = state.borderColor.cgColor
  }
}

private extension CGFloat {
  static let borderWidth: CGFloat = 1.5
  static let cornerRadius: CGFloat = 16
}
