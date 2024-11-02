import TKUIKit
import UIKit

final class AmountInputViewController: GenericViewViewController<AmountInputView> {
  private let viewModel: AmountInputViewModel
  
  private let sendAmountTextFieldFormatter: SendAmountTextFieldFormatter = {
    let numberFormatter = NumberFormatter()
    numberFormatter.groupingSize = 3
    numberFormatter.usesGroupingSeparator = true
    numberFormatter.maximumIntegerDigits = 16
    numberFormatter.roundingMode = .down
    let amountInputFormatController = SendAmountTextFieldFormatter(
      currencyFormatter: numberFormatter
    )
    return amountInputFormatController
  }()
  
  init(viewModel: AmountInputViewModel) {
    self.viewModel = viewModel
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func becomeFirstResponder() -> Bool {
    return customView.valueView.inputControl.inputTextField.becomeFirstResponder()
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    setup()
    setupBindings()
    viewModel.viewDidLoad()
  }
  
  private func setup() {
    customView.valueView.inputControl.inputTextField.delegate = sendAmountTextFieldFormatter
    customView.valueView.convertedButton.addAction(UIAction(handler: { [weak self] _ in
      self?.viewModel.toggle()
    }), for: .touchUpInside)
    customView.valueView.inputControl.inputTextField.addAction(UIAction(handler: { [weak self] _ in
      guard let self else { return }
      let text = customView.valueView.inputControl.inputTextField.text ?? ""
      let unformatted = sendAmountTextFieldFormatter.unformatString(text)
      viewModel.didEditText(unformatted)
    }), for: .editingChanged)
  }
  
  private func setupBindings() {
    viewModel.didUpdateMaximumFractionDigits = { [weak self] in
      self?.sendAmountTextFieldFormatter.maximumFractionDigits = $0
    }
    viewModel.didUpdateValueViewConfiguration = { [weak self] in
      self?.customView.valueView.configuration = $0
    }
    viewModel.didUpdateInputText = { [weak self] in
      guard let self else { return }
//      let unformatted = sendAmountTextFieldFormatter.unformatString($0)
      customView.valueView.inputControl.setInputValue(string: $0)
    }
    viewModel.didUpdateBalanceViewConfiguration = { [weak self] in
      self?.customView.balanceView.configuration = $0
    }
    viewModel.didUpdateMaxButtonIsSelected = { [weak self] in
      self?.customView.balanceView.maxButton.isSelected = $0
    }
  }
}
