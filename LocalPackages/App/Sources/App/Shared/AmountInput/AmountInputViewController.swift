import UIKit
import TKUIKit

final class AmountInputViewController: GenericViewViewController<AmountInputView> {
  
  var didUpdateText: ((String?) -> Void)?
  var didToggle: (() -> Void)?
  var didTapTokenPickerButton: (() -> Void)?
  
  var inputSymbol = "" {
    didSet {
      customView.inputControl.currencyLabel.text = inputSymbol
    }
  }
  var inputValue = "" {
    didSet {
      didUpdateInputValue()
    }
  }
  var convertedValue: String = "" {
    didSet {
      let styled = convertedValue.withTextStyle(TKTextStyle.body1, color: .Text.secondary)
      customView.convertedButton.configuration.content.title = .init(.attributedString(styled))
    }
  }

  var convertedIcon: UIImage?  {
    didSet {
      customView.convertedButton.configuration.content.icon = convertedIcon
    }
  }
  
  var maximumFractionDigits: Int {
    get {
      sendAmountTextFieldFormatter.maximumFractionDigits
    }
    set {
      sendAmountTextFieldFormatter.maximumFractionDigits = newValue
    }
  }
  
  var isTokenPickerAvailable: Bool = true {
    didSet {
      customView.inputControl.tokenPickerButton.isHidden = !isTokenPickerAvailable
      customView.inputControl.setNeedsLayout()
    }
  }
  
  private let sendAmountTextFieldFormatter: SendAmountTextFieldFormatter = {
    let numberFormatter = NumberFormatter()
    numberFormatter.groupingSeparator = " "
    numberFormatter.groupingSize = 3
    numberFormatter.usesGroupingSeparator = true
    numberFormatter.decimalSeparator = Locale.current.decimalSeparator
    numberFormatter.maximumIntegerDigits = 16
    numberFormatter.roundingMode = .down
    let amountInputFormatController = SendAmountTextFieldFormatter(
      currencyFormatter: numberFormatter
    )
    return amountInputFormatController
  }()
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    setup()
    customView.inputControl.amountTextField.delegate = sendAmountTextFieldFormatter
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    
    customView.inputControl.amountTextField.becomeFirstResponder()
  }
  
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    customView.inputControl.amountTextField.becomeFirstResponder()
  }
  
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    customView.layoutIfNeeded()
    customView.convertedButton.layer.cornerRadius = customView.convertedButton.frame.height/2
  }
}

private extension AmountInputViewController {
  func setup() {
    customView.convertedButton.configuration.iconTintColor = .Text.secondary
    customView.convertedButton.configuration.iconPosition = .right
    customView.convertedButton.configuration.contentAlpha = [.highlighted:  0.48]
    customView.convertedButton.configuration.spacing = 8
    customView.convertedButton.configuration.contentPadding = .convertedButtonContentInsets
    
    customView.inputControl.didUpdateText = { [weak self] text in
      self?.didUpdateText?(self?.sendAmountTextFieldFormatter.unformatString(text))
    }
    
    customView.convertedButton.addAction(UIAction(handler: { [weak self] _ in
      self?.didToggle?()
    }), for: .touchUpInside)
    
    customView.inputControl.tokenPickerButton.addAction(UIAction(handler: { [weak self] _ in
      self?.didTapTokenPickerButton?()
    }), for: .touchUpInside)
  }
  
  func didUpdateInputValue() {
    let formatted = sendAmountTextFieldFormatter.formatString(sendAmountTextFieldFormatter.unformatString(inputValue))
    customView.inputControl.setInputValue(formatted)
  }
}

private extension UIEdgeInsets {
  static let convertedButtonContentInsets = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
}
