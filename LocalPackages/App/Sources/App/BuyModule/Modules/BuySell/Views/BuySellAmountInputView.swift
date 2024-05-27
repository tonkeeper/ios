import UIKit
import TKUIKit

final class BuySellAmountInputView: AmountInputView, ConfigurableView {
  
  var didTapConvertedButton: (() -> Void)?
  
  let minAmountLabel: UILabel = {
    let label = UILabel()
    label.textAlignment = .center
    label.font = TKTextStyle.label2.font
    label.textColor = .Text.tertiary
    return label
  }()
  
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
    let minimum: Minimum
  }
  
  func configure(model: Model) {
    inputControl.currencyLabel.text = model.inputCurrency
    convertedButton.setTitle("\(model.convertedAmount.value) \(model.convertedAmount.currency)", for: .normal)
    minAmountLabel.text = "\(model.minimum.title): \(model.minimum.amount.value) \(model.minimum.amount.currency)"
  }
  
  override func setup() {
    inputControl.tokenPickerButton.isHidden = true
    inputControl.isCurrencyLabelAlignedToLastBaseline = true
    inputControl.amountTextField.font = TKTextStyle.amountInput.font
    inputControl.currencyLabel.font = TKTextStyle.num2.font
    
    container.addSubview(minAmountLabel)
    
    convertedButton.addAction(UIAction(handler: { [weak self] _ in
      self?.didTapConvertedButton?()
    }), for: .touchUpInside)
    
    super.setup()
  }
  
  override func setupConstraints() {
    super.setupConstraints()
    
    container.snp.remakeConstraints { make in
      make.left.right.equalTo(self)
      make.top.equalTo(self).offset(CGFloat.inputControlTopPadding)
      make.bottom.equalTo(self)
    }
    
    inputControl.snp.remakeConstraints { make in
      make.top.equalTo(container)
      make.left.right.equalTo(container).inset(CGFloat.contentVerticalPadding)
      make.height.equalTo(CGFloat.inputControlHeight)
    }
    
    convertedButton.snp.remakeConstraints { make in
      make.top.equalTo(inputControl.snp.bottom)
      make.left.greaterThanOrEqualTo(container).offset(CGFloat.contentVerticalPadding)
      make.right.lessThanOrEqualTo(container).offset(-CGFloat.contentVerticalPadding)
      make.centerX.equalTo(container)
      make.height.equalTo(CGFloat.convertedButtonHeight)
    }
    
    minAmountLabel.snp.remakeConstraints { make in
      make.top.equalTo(convertedButton.snp.bottom)
      make.left.right.equalTo(container)
      make.bottom.equalTo(container)
    }
  }
}

private extension CGFloat {
  static let height: CGFloat = 178
  static let contentVerticalPadding: CGFloat = 16
  static let inputControlTopPadding: CGFloat = 24
  static let inputControlHeight: CGFloat = 70
  static let convertedButtonHeight: CGFloat = 40
}
