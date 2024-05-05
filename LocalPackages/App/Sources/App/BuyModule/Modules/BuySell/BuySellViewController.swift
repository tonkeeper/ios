import UIKit
import TKUIKit

final class BuySellViewController: GenericViewViewController<BuySellView>, KeyboardObserving {
  private let viewModel: BuySellViewModel
  
  init(viewModel: BuySellViewModel) {
    self.viewModel = viewModel
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    setup()
    setupBindings()
    setupViewEvents()
    viewModel.viewDidLoad()
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    
    registerForKeyboardEvents()
    customView.amountInputView.amountTextField.becomeFirstResponder()
  }

  public override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    
    unregisterFromKeyboardEvents()
  }
  
  public func keyboardWillShow(_ notification: Notification) {
    guard let animationDuration = notification.keyboardAnimationDuration,
    let keyboardHeight = notification.keyboardSize?.height else { return }
    UIView.animate(withDuration: animationDuration, delay: 0, options: .curveEaseInOut) {
      self.customView.scrollView.contentInset.bottom = keyboardHeight
    }
  }
  
  public func keyboardWillHide(_ notification: Notification) {
    guard let animationDuration = notification.keyboardAnimationDuration else { return }
    UIView.animate(withDuration: animationDuration, delay: 0, options: .curveEaseInOut) {
      self.customView.scrollView.contentInset.bottom = 0
    }
  }
}

private extension BuySellViewController {
  func setup() {
    title = "Buy Sell"
    view.backgroundColor = .Background.page
      
    customView.amountInputView.backgroundColor = .Background.content
    customView.amountInputView.amountTokenTitleLabel.textColor = .Text.secondary
    customView.amountInputView.convertedAmountLabel.textColor = .Text.secondary
    customView.amountInputView.convertedCurrencyLabel.textColor = .Text.secondary
    customView.amountInputView.minAmountLabel.textColor = .Text.tertiary
    
    customView.amountInputView.amountTextField.delegate = viewModel.buySellAmountTextFieldFormatter
  }
  
  func setupBindings() {
    viewModel.didUpdateModel = { [weak self] model in
      guard let customView = self?.customView else { return }
      
      if let amountModel = model.amount {
        customView.amountInputView.isHidden = false
        customView.amountInputView.amountTextField.text = amountModel.text
        customView.amountInputView.amountTokenTitleLabel.text = amountModel.token.title
      } else {
        customView.amountInputView.isHidden = true
      }
      
      customView.amountInputView.convertedAmountLabel.text = model.balance.converted
      customView.amountInputView.convertedCurrencyLabel.text = model.balance.currency.rawValue
      
      customView.amountInputView.minAmountLabel.text = "Min. amount: 50 TON"
      
      customView.continueButton.configuration.content = TKButton.Configuration.Content(title: .plainString(model.button.title))
      customView.continueButton.configuration.isEnabled = model.button.isEnabled
      customView.continueButton.configuration.showsLoader = model.button.isActivity
      customView.continueButton.configuration.action = model.button.action
    }
  }
  
  func setupViewEvents() {
    customView.amountInputView.didUpdateText = { [weak viewModel] in
      viewModel?.didInputAmount($0 ?? "")
    }
  }
}
