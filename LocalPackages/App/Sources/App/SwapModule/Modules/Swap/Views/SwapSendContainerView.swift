import UIKit
import TKUIKit
import SnapKit

final class SwapSendContainerView: UIView, ConfigurableView {
  
  let inputContainerView = SwapInputContainerView(inputViewHeight: 48, topOffset: 0)
  
  var maxButton: TKButton {
    inputContainerView.amountHeaderView.actionButton
  }
  
  var textField: PlainTextField {
    inputContainerView.amountInputView.textField
  }
  
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
