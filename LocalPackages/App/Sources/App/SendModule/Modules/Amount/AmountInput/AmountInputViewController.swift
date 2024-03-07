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
  var convertedValue = "" {
    didSet {
      customView.convertedButton.setTitle(convertedValue, for: .normal)
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
}

private extension AmountInputViewController {
  func setup() {
    
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
