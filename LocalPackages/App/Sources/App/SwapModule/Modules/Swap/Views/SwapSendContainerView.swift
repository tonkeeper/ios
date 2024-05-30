import UIKit
import TKUIKit
import SnapKit

final class SwapSendContainerView: UIView, ConfigurableView {
  
  var maxButton: TKButton {
    inputContainerView.amountHeaderView.actionButton
  }
  
  var textField: PlainTextField {
    inputContainerView.amountInputView.textField
  }
  
  let inputContainerView = SwapInputContainerView(inputViewHeight: 48, topOffset: 0)
  
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

private extension SwapSendContainerView {
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
