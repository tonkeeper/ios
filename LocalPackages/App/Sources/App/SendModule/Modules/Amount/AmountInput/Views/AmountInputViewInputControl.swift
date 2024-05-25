import UIKit
import TKUIKit

final class AmountInputViewInputControl: UIControl {
  
  var didUpdateText: ((String?) -> Void)?
  
  var isCurrencyLabelAlignedToLastBaseline = false
  
  let amountTextField: UITextField = {
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
  
  let currencyLabel: UILabel = {
    let label = UILabel()
    label.font = .currencyInputFont
    label.textColor = .Text.secondary
    label.textAlignment = .center
    label.setContentCompressionResistancePriority(.required, for: .horizontal)
    return label
  }()
  
  let tokenPickerButton: UIButton = {
    let button = UIButton(type: .system)
    button.setImage(.TKUIKit.Icons.Size16.switch, for: .normal)
    button.backgroundColor = .Button.tertiaryBackground
    button.tintColor = .Button.tertiaryForeground
    button.layer.cornerRadius = 14
    return button
  }()
  
  private let containerView = UIView()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    
    amountTextField.sizeToFit()
    currencyLabel.sizeToFit()
    
    amountTextField.frame.origin = CGPoint(x: 0, y: bounds.height/2 - amountTextField.frame.height/2)
    currencyLabel.frame.origin = CGPoint(x: amountTextField.frame.maxX + .currencyInputLeftInset, y: bounds.height/2 - currencyLabel.frame.height/2 + 2)
    tokenPickerButton.frame = CGRect(
      origin: CGPoint(x: currencyLabel.frame.maxX + .tokenPickerLeftInset, y: bounds.height/2 - .tokenPickerButtonSide/2 + 2),
      size: CGSize(width: .tokenPickerButtonSide, height: .tokenPickerButtonSide)
    )
    
    if isCurrencyLabelAlignedToLastBaseline {
      alignCurrencyLabelToLastBaseline()
    }
    
    var containerWidth = amountTextField.frame.width + currencyLabel.frame.width + .currencyInputLeftInset
    if !tokenPickerButton.isHidden {
      containerWidth += .tokenPickerButtonSide + .tokenPickerLeftInset
    }
    let containerHeight = bounds.height
    
    containerView.frame = CGRect(
      origin: CGPoint(x: bounds.width/2 - containerWidth/2, y: 0),
      size: CGSize(width: containerWidth, height: containerHeight)
    )
  }
  
  override var intrinsicContentSize: CGSize {
    return CGSize(width: UIView.noIntrinsicMetric, height: 50)
  }
  
  func setInputValue(_ inputValue: String?) {
    amountTextField.text = inputValue
    updateAppearance()
  }
}

private extension AmountInputViewInputControl {
  func setup() {
    amountTextField.addTarget(
      self,
      action: #selector(didEditText),
      for: .editingChanged
    )
    
    addAction(UIAction(handler: { [weak self] _ in
      self?.amountTextField.becomeFirstResponder()
    }), for: .touchUpInside)
    
    addSubview(containerView)
    containerView.addSubview(amountTextField)
    containerView.addSubview(currencyLabel)
    containerView.addSubview(tokenPickerButton)
  }
  
  @objc func didEditText() {
    updateAppearance()
    didUpdateText?(amountTextField.text)
  }
  
  func updateAppearance() {
    let inputWidth = (amountTextField.text ?? "").width(font: .amountInputFont)
    let currencyWidth = (currencyLabel.text ?? "").width(font: .currencyInputFont)
    let width = inputWidth + currencyWidth + .tokenPickerLeftInset
    let availableWidth = bounds.width - .tokenPickerButtonSide - .currencyInputLeftInset - .sidePadding - .sidePadding
    guard availableWidth > 0 else { return }

    if width >= availableWidth {
      let aspect = availableWidth / width
      amountTextField.transform = CGAffineTransform(scaleX: aspect, y: aspect)
      currencyLabel.transform = CGAffineTransform(scaleX: aspect, y: aspect)
    } else {
      amountTextField.transform = .identity
      currencyLabel.transform = .identity
    }
    setNeedsLayout()
  }
  
  func makeSmallerFont(_ font: UIFont, string: String, width: CGFloat) -> UIFont {
    let smallerFont = font.withSize(font.pointSize - 1)
    let stringWidth = string.width(font: smallerFont)
    if stringWidth >= width {
      return makeSmallerFont(smallerFont, string: string, width: width)
    } else {
      return smallerFont
    }
  }
  
  func alignCurrencyLabelToLastBaseline() {
    guard let amountTextFieldFont = amountTextField.font else { return }
    guard let currencyLabelFont = currencyLabel.font else { return }
    let aspect = currencyLabel.transform.d
    let amountTextFieldLastBaseline = amountTextFieldFont.withSize(amountTextFieldFont.pointSize * aspect).ascender
    let currencyLabelLabelLastBaseline = currencyLabelFont.withSize(currencyLabelFont.pointSize * aspect).ascender
    let currencyLabelOriginY = amountTextField.frame.origin.y + (amountTextFieldLastBaseline - currencyLabelLabelLastBaseline) + 1 * aspect
    currencyLabel.frame.origin.y = currencyLabelOriginY
  }
}

private extension String {
  func width(font: UIFont) -> CGFloat {
    let constraintRect = CGSize(width: .greatestFiniteMagnitude,
                                height: font.pointSize)
    let boundingBox = self.boundingRect(with: constraintRect,
                                        options: [.usesLineFragmentOrigin, .usesFontLeading],
                                        attributes: [.font: font],
                                        context: nil)
    
    return ceil(boundingBox.width)
  }
}

private extension UIFont {
  static var amountInputFont: UIFont = TKTextStyle.num1.font
  static var currencyInputFont: UIFont = TKTextStyle.num2.font
}

private extension CGFloat {
  static let sidePadding: CGFloat = 16
  static let tokenPickerButtonSide: CGFloat = 28
  static let amountTextFieldBottomInset: CGFloat = 10
  static let currencyInputLeftInset: CGFloat = 8
  static let currencyInputBottomInset: CGFloat = 12
  static let tokenPickerLeftInset: CGFloat = 6
  static let tokenPickerBottomInset: CGFloat = 12
}
