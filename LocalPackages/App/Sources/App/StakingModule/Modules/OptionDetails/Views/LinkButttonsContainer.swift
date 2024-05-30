import UIKit
import TKUIKit
import SnapKit
import TKCore

final class LinkButtonsContainer: UIView, ConfigurableView {
  private let labelContainer = UIView()
  private let label = UILabel()
  private let rootVStack: UIStackView = {
    let stack = UIStackView()
    stack.axis = .vertical
    stack.spacing = 14

    return stack
  }()
  
  private let buttonsVStack: UIStackView = {
    let stack = UIStackView()
    stack.axis = .vertical
    stack.spacing = 8

    return stack
  }()
  
  struct Model {
    let title: String
    let buttons: [[TKButton]]
  }
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  func configure(model: Model) {
    label.attributedText = model.title.withTextStyle(
      .h3,
      color: .Text.primary,
      alignment: .left
    )
    
    if !buttonsVStack.arrangedSubviews.isEmpty {
      buttonsVStack.removeAllArrangedSubviews()
    }
    
    for row in model.buttons {
      let rowStack = createHStack(row: row)
      buttonsVStack.addArrangedSubview(rowStack)
    }
  }
}

// MARK: - Private methods

private extension LinkButtonsContainer {
  func setup() {
    label.layout(in: labelContainer) {
      $0.left.equalToSuperview().offset(2)
      $0.bottom.trailing.top.equalToSuperview()
    }
    
    rootVStack.addArrangedSubview(labelContainer)
    rootVStack.addArrangedSubview(buttonsVStack)
    
    rootVStack.fill(in: self)
  }
  
  func createHStack(row: [TKButton]) -> UIStackView {
    let stack = UIStackView()
    stack.axis = .horizontal
    stack.spacing = 8
    
    for button in row {
      stack.addArrangedSubview(button)
    }
    
    stack.addSpacer()
    return stack
  }
}

private extension UIStackView {
    @discardableResult
    func removeAllArrangedSubviews() -> [UIView] {
        return arrangedSubviews.reduce([UIView]()) { $0 + [removeArrangedSubView($1)] }
    }

    func removeArrangedSubView(_ view: UIView) -> UIView {
        removeArrangedSubview(view)
        NSLayoutConstraint.deactivate(view.constraints)
        view.removeFromSuperview()
        return view
    }
}

extension UIStackView {
  func addSpacer() {
    addArrangedSubview(UIView())
  }
}

