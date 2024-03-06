import UIKit
import TKUIKit
import SnapKit

extension SendPickerCell {
  final class EmptyAccessoriesView: UIView, ConfigurableView {
    
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
      struct Button {
        let model: TKHeaderButton.Model
        let action: (() -> Void)
      }
      let buttons: [Button]
    }
    
    func configure(model: Model) {
      stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
      model.buttons.forEach {
        let button = TKHeaderButton(category: .tertiary)
        button.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        button.configure(model: $0.model)
        button.setTapAction($0.action)
        stackView.addArrangedSubview(button)
      }
    }
  }
}

private extension SendPickerCell.EmptyAccessoriesView {
  func setup() {
    addSubview(stackView)

    setupConstraints()
  }
  
  func setupConstraints() {
    setContentHuggingPriority(.defaultHigh, for: .horizontal)
    stackView.setContentHuggingPriority(.defaultHigh, for: .horizontal)
    
    stackView.snp.makeConstraints { make in
      make.right.left.equalTo(self)
      make.centerY.equalTo(self)
    }
  }
}
