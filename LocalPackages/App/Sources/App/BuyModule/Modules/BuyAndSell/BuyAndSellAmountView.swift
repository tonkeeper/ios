import UIKit
import TKUIKit

final class BuyAndSellAmountView: UIView {
  var didUpdateText: ((String?) -> Void)?
  
  private lazy var textFieldContainer = UIView()
  lazy var convertedAmountContainer = UIView()
  
  lazy var tonLabel: UILabel = {
    let label = UILabel()
    label.font = .currencyFont
    label.textColor = .Text.secondary
    return label
  }()
  
  lazy var convertedAmountLabel: UILabel = {
    let label = UILabel()
    label.font = .convertedCurrencyFont
    label.textColor = .Text.tertiary
    return label
  }()
  
  lazy var minAmountLabel: UILabel = {
    let label = UILabel()
    label.font = .minAmountFont
    label.textColor = .Text.secondary
    label.textAlignment = .center
    return label
  }()
    
  lazy var amountTextField: UITextField = {
    let textField = UITextField()
    textField.font = .amountInputFont
    textField.textColor = .Text.primary
    textField.textAlignment = .right
    textField.keyboardAppearance = .dark
    textField.keyboardType = .decimalPad
    textField.tintColor = .Accent.blue
    textField.setContentHuggingPriority(.required, for: .horizontal)
    return textField
  }()
  
  // MARK: - Init

  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  // MARK: - Layout
  
  override func layoutSubviews() {
    super.layoutSubviews()
    
    convertedAmountContainer.layer.cornerRadius = convertedAmountContainer.bounds.height/2
  }
}

// MARK: - Private

private extension BuyAndSellAmountView {
  func setup() {
    backgroundColor = .Background.content
    addSubview(textFieldContainer)
    textFieldContainer.addSubview(amountTextField)
    textFieldContainer.addSubview(tonLabel)
    addSubview(convertedAmountContainer)
    convertedAmountContainer.addSubview(convertedAmountLabel)
    addSubview(minAmountLabel)
    
    convertedAmountContainer.layer.borderWidth = 1.5
    convertedAmountContainer.layer.borderColor = UIColor.Button.tertiaryBackground.cgColor
    
    tonLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
    
    textFieldContainer.snp.makeConstraints { make in
      make.centerX.equalToSuperview()
      make.leading.greaterThanOrEqualToSuperview().offset(24)
      make.trailing.lessThanOrEqualToSuperview().offset(-24)
      make.top.equalToSuperview().offset(24)
    }
    
    amountTextField.snp.makeConstraints { make in
      make.top.equalTo(textFieldContainer).offset(10)
      make.bottom.equalTo(textFieldContainer).offset(-10)
      make.leading.equalTo(textFieldContainer)
      make.trailing.equalTo(tonLabel.snp.leading).offset(-5)
    }
    
    tonLabel.snp.makeConstraints { make in
      make.top.equalTo(textFieldContainer).offset(22)
      make.bottom.equalTo(textFieldContainer).offset(-12)
      make.trailing.equalTo(textFieldContainer)
    }
    
    convertedAmountLabel.snp.makeConstraints { make in
      make.edges.equalToSuperview().inset(UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16))
    }
    
    convertedAmountContainer.snp.makeConstraints { make in
      make.centerX.equalToSuperview()
      make.top.equalTo(textFieldContainer.snp.bottom)
    }
    
    minAmountLabel.snp.makeConstraints { make in
      make.leading.equalToSuperview().offset(16)
      make.trailing.equalToSuperview().offset(-16)
      make.bottom.equalToSuperview().offset(-12)
      make.top.equalTo(convertedAmountContainer.snp.bottom).offset(12)
    }
    
    amountTextField.addTarget(
      self,
      action: #selector(didEditText),
      for: .editingChanged
    )
  }
  
  @objc func didEditText() {
    didUpdateText?(amountTextField.text)
  }
}

private extension UIFont {
  static var amountInputFont: UIFont = TKTextStyle.buy.font
  static var currencyFont: UIFont = TKTextStyle.num2.font
  static var convertedCurrencyFont: UIFont = TKTextStyle.body1.font
  static var minAmountFont: UIFont = TKTextStyle.body2.font
}
