import UIKit
import TKUIKit
import SnapKit

extension SendPickerCell {
  final class EmptyAccessoriesView: UIView, ConfigurableView {
    
    private let pasteButton = TKHeaderButton(category: .tertiary)
    
    private let stackView: UIStackView = {
      let stackView = UIStackView()
      return stackView
    }()
    
    override init(frame: CGRect) {
      super.init(frame: frame)
      setup()
    }
    
    required init?(coder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }
    
    struct Model {
      let pasteButtonAction: () -> Void
    }
    
    func configure(model: Model) {
      pasteButton.enumerateEventHandlers { action, targetAction, event, stop in
        if let action = action {
          pasteButton.removeAction(action, for: event)
        }
      }
      pasteButton.addAction(UIAction(handler: { _ in
        model.pasteButtonAction()
      }), for: .touchUpInside)
    }
  }
}

private extension SendPickerCell.EmptyAccessoriesView {
  func setup() {
    addSubview(stackView)
    stackView.addArrangedSubview(pasteButton)
    
    pasteButton.configure(model: TKButton.Model(title: "Paste"))
    
    setupConstraints()
  }
  
  func setupConstraints() {
    setContentHuggingPriority(.defaultHigh, for: .horizontal)
    pasteButton.setContentHuggingPriority(.defaultHigh, for: .horizontal)
    stackView.setContentHuggingPriority(.defaultHigh, for: .horizontal)
    
    stackView.snp.makeConstraints { make in
      make.right.left.equalTo(self)
      make.centerY.equalTo(self)
    }
  }
}
