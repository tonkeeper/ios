import UIKit
import TKUIKit

final class SettingsButtonCell: UICollectionViewCell {
  var padding: UIEdgeInsets = .zero
  
  private let stackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .vertical
    return stackView
  }()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    stackView.frame = bounds.inset(by: padding)
  }
  
  override func sizeThatFits(_ size: CGSize) -> CGSize {
    let contentSize = CGSize(
      width: size.width - padding.left - padding.right,
      height: size.height - padding.top - padding.bottom
    )
    let stackViewSize = stackView.systemLayoutSizeFitting(
      contentSize,
      withHorizontalFittingPriority: .required,
      verticalFittingPriority: .defaultHigh
    )
    return CGSize(
      width: stackViewSize.width + padding.left + padding.right,
      height: stackViewSize.height + padding.top + padding.bottom
    )
  }
  
  struct Model: Identifiable, Hashable {
    struct Button {
      let category: TKUIActionButtonCategory
      let size: TKUIActionButtonSize
      let model: TKUIActionButton.Model
      let action: () -> Void
    }
    let id: String
    let padding: UIEdgeInsets
    let buttons: [Button]
    
    func hash(into hasher: inout Hasher) {
      hasher.combine(id)
    }
    
    static func ==(lhs: Model, rhs: Model) -> Bool {
      lhs.id == rhs.id
    }
  }
  
  func configure(model: Model) {
    self.padding = model.padding
    stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
    model.buttons.forEach { buttonModel in
      let button = TKUIActionButton(
        category: buttonModel.category,
        size: buttonModel.size
      )
      button.configure(model: buttonModel.model)
      button.addTapAction(buttonModel.action)
      stackView.addArrangedSubview(button)
    }
    setNeedsLayout()
  }
}

private extension SettingsButtonCell {
  func setup() {
    addSubview(stackView)
  }
}
