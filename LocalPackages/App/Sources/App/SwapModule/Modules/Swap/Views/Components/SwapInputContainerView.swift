import UIKit
import TKUIKit
import SnapKit

final class SwapInputContainerView: UIView, ConfigurableView {
  
  let amountHeaderView = SwapAmountHeaderView()
  let amountInputView = SwapAmountInputView()
  
  private let inputViewHeight: CGFloat
  private let topOffset: CGFloat
  
  init(inputViewHeight: CGFloat, topOffset: CGFloat) {
    self.inputViewHeight = inputViewHeight
    self.topOffset = topOffset
    super.init(frame: .zero)
    self.setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  struct Model {
    typealias TokenButton = SwapAmountInputView.Model.TokenButton
    typealias TextField = SwapAmountInputView.Model.TextField
    
    let header: SwapAmountHeaderView.Model
    let tokenButton: TokenButton
    let textField: TextField
  }
  
  func configure(model: Model) {
    amountHeaderView.configure(model: model.header)
    
    amountInputView.configure(
      model: SwapAmountInputView.Model(
        tokenButton: model.tokenButton,
        textField: model.textField
      )
    )
  }
  
  func setBalanceTitle(_ title: String?) {
    amountHeaderView.rightTitleLabel.attributedText = title?.withTextStyle(.body2, color: .Text.secondary, alignment: .right)
    amountHeaderView.rightTitleLabel.isHidden = title == nil
  }
}

private extension SwapInputContainerView {
  func setup() {
    addSubview(amountHeaderView)
    addSubview(amountInputView)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    amountHeaderView.snp.makeConstraints { make in
      make.top.equalTo(self).offset(topOffset)
      make.left.equalTo(self).offset(CGFloat.horizontalPadding)
      make.right.equalTo(self).inset(CGFloat.horizontalPadding)
      make.height.equalTo(CGFloat.headerViewHeight)
    }
    
    amountInputView.snp.makeConstraints { make in
      make.top.equalTo(amountHeaderView.snp.bottom)
      make.left.equalTo(self).offset(CGFloat.horizontalPadding)
      make.right.equalTo(self).inset(CGFloat.horizontalPadding)
      make.height.equalTo(inputViewHeight)
    }
  }
}

private extension CGFloat {
  static let headerViewHeight: CGFloat = 44
  static let horizontalPadding: CGFloat = 16
}
