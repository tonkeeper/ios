import UIKit
import TKUIKit

final class BuySellAmountInputView: UIView {
  
  let inputControl: AmountInputViewInputControl = {
    let inputControl = AmountInputViewInputControl()
    inputControl.amountTextField.font = TKTextStyle.amountInput.font
    inputControl.currencyLabel.font = TKTextStyle.h2.font
    inputControl.amountTextField.textColor = .Text.primary
    inputControl.currencyLabel.textColor = .Text.secondary
    inputControl.tokenPickerButton.isHidden = true
    inputControl.isCurrencyLabelAlignedToLastBaseline = true
    return inputControl
  }()
  
  let convertedAmountLabel: UILabel = {
    let label = UILabel()
    label.font = TKTextStyle.label1.font
    return label
  }()
  
  let convertedCurrencyLabel: UILabel = {
    let label = UILabel()
    label.font = TKTextStyle.label1.font
    return label
  }()
  
  let minAmountLabel: UILabel = {
    let label = UILabel()
    label.textAlignment = .center
    label.font = TKTextStyle.label2.font
    return label
  }()
  
  private let convertedContainer: UIView = {
    let view = UIView()
    view.layer.borderWidth = 1.5
    view.layer.borderColor = UIColor.Button.tertiaryBackground.cgColor
    view.layer.cornerRadius = .convertedContainerCornerRadius
    view.layer.cornerCurve = .continuous
    return view
  }()
    
  override var intrinsicContentSize: CGSize {
    CGSize(width: UIView.noIntrinsicMetric, height: .height)
  }
  
  // MARK: - Init
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    self.setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  // MARK: - Setup
  
  private func setup() {
    addSubview(inputControl)
    addSubview(minAmountLabel)
    addSubview(convertedContainer)
    addSubview(convertedAmountLabel)
    addSubview(convertedCurrencyLabel)
    
    setupConstraints()
  }
  
  private func setupConstraints() {
    inputControl.snp.makeConstraints { make in
      make.top.equalTo(self).offset(CGFloat.inputControlTopPadding)
      make.left.right.equalTo(self).inset(8)
      make.height.equalTo(CGFloat.inputControlHeight)
    }
    
    convertedContainer.snp.makeConstraints { make in
      make.top.equalTo(inputControl.snp.bottom)
      make.left.equalTo(convertedAmountLabel).offset(-CGFloat.contentVerticalPadding)
      make.right.equalTo(convertedCurrencyLabel).offset(CGFloat.contentVerticalPadding)
      make.height.equalTo(CGFloat.convertedContainerHeight)
      make.centerX.equalTo(self)
    }
    
    convertedAmountLabel.snp.makeConstraints { make in
      make.centerY.equalTo(convertedContainer)
    }
    
    convertedCurrencyLabel.snp.makeConstraints { make in
      make.left.equalTo(convertedAmountLabel.snp.right).offset(4)
      make.lastBaseline.equalTo(convertedAmountLabel)
    }
    
    minAmountLabel.snp.makeConstraints { make in
      make.top.equalTo(convertedContainer.snp.bottom).offset(12)
      make.left.right.equalTo(self).inset(CGFloat.contentVerticalPadding)
      make.height.equalTo(CGFloat.minAmountLabelHeight)
    }
  }
}

private extension CGFloat {
  static let height: CGFloat = 178
  static let contentVerticalPadding: CGFloat = 16
  static let inputControlTopPadding: CGFloat = 24
  static let inputControlHeight: CGFloat = 70
  static let convertedContainerHeight: CGFloat = 40
  static let convertedContainerCornerRadius: CGFloat = .convertedContainerHeight / 2
  static let minAmountLabelHeight: CGFloat = 20
}
