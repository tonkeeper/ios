import UIKit
import TKUIKit
import SnapKit

final class SwapRecieveContainerView: UIView, ConfigurableView {
  
  var textField: PlainTextField {
    inputContainerView.amountInputView.textField
  }
  
  let inputContainerView = SwapInputContainerView(inputViewHeight: 52, topOffset: 12)
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    self.setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  struct Model {
    let inputContainerModel: SwapInputContainerView.Model
  }
  
  func configure(model: Model) {
    inputContainerView.configure(model: model.inputContainerModel)
  }
}

private extension SwapRecieveContainerView {
  private func setup() {
    addSubview(inputContainerView)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    inputContainerView.snp.makeConstraints { make in
      make.edges.equalTo(self)
    }
  }
}
