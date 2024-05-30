import UIKit
import TKUIKit

final class StakeAmountInputView: AmountInputView, ConfigurableView {
  
  var didTapConvertedButton: (() -> Void)?
  
  override var intrinsicContentSize: CGSize {
    CGSize(width: UIView.noIntrinsicMetric, height: .height)
  }
  
  struct Model {
    struct Amount {
      let value: String
      let currency: String
    }
    
    struct Minimum {
      let title: String
      let amount: Amount
    }
    
    let inputCurrency: String
    let convertedAmount: Amount
  }
  
  func configure(model: Model) {
    inputControl.currencyLabel.text = model.inputCurrency
    convertedButton.setTitle("\(model.convertedAmount.value) \(model.convertedAmount.currency)", for: .normal)
  }
  
  override func setup() {
    inputControl.tokenPickerButton.isHidden = true
    inputControl.isCurrencyLabelAlignedToLastBaseline = true
    inputControl.amountTextField.font = TKTextStyle.amountInput.font
    inputControl.currencyLabel.font = TKTextStyle.num2.font
    
    convertedButton.addAction(UIAction(handler: { [weak self] _ in
      self?.didTapConvertedButton?()
    }), for: .touchUpInside)
    
    super.setup()
  }
  
  override func setupConstraints() {
    super.setupConstraints()
    
    inputControl.snp.remakeConstraints { make in
      make.top.equalTo(container)
      make.left.right.equalTo(container).inset(CGFloat.contentHorizontalPadding)
      make.height.equalTo(CGFloat.inputControlHeight)
    }
    
    convertedButton.snp.remakeConstraints { make in
      make.top.equalTo(inputControl.snp.bottom)
      make.left.greaterThanOrEqualTo(container).offset(CGFloat.contentHorizontalPadding)
      make.right.lessThanOrEqualTo(container).offset(-CGFloat.contentHorizontalPadding)
      make.bottom.centerX.equalTo(container)
      make.height.equalTo(CGFloat.convertedButtonHeight)
    }
  }
}

private extension CGFloat {
  static let height: CGFloat = 188
  static let contentHorizontalPadding: CGFloat = 16
  static let inputControlTopPadding: CGFloat = 24
  static let inputControlHeight: CGFloat = 70
  static let convertedButtonHeight: CGFloat = 40
}
