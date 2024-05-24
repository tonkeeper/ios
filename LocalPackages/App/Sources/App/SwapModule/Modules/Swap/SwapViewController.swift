import UIKit
import TKUIKit
import TKLocalize

final class SwapViewController: GenericViewViewController<SwapView>, KeyboardObserving {
  private let viewModel: SwapViewModel
  
  init(viewModel: SwapViewModel) {
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
    customView.sendView.amountTextField.becomeFirstResponder()
    customView.receiveView.amountTextField.isEnabled = false
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

private extension SwapViewController {
  func setup() {
    title = TKLocales.Swap.title
    setupSwapInputs()
  }

  func setupSwapInputs() {
    customView.swapInputsButton.configuration.action = { [weak self] in
      guard let self else { return }
      let oldCenter = self.customView.inputView1.center
      self.customView.inputView1.swapField = .receive
      self.customView.inputView2.swapField = .send
      UIView.spring {
        self.customView.inputView1.center = self.customView.inputView2.center
        self.customView.inputView2.center = oldCenter
      }
    }
  }
  
  func setupBindings() {
    viewModel.didUpdateModel = { [weak self] model in
      guard let self else { return }
      self.customView.sendView.chooseTokenView.token = model.send.token
      self.customView.sendView.amountTextField.text = model.send.amount
      self.customView.sendView.updateTotalBalance(model.send.balance)
      
      self.customView.receiveView.chooseTokenView.token = model.receive.token
      self.customView.receiveView.amountTextField.text = model.receive.amount
      self.customView.receiveView.updateTotalBalance(model.receive.balance)
      
      self.customView.swapInputsButton.isEnabled = model.status.isValidReceiveToken

      if model.status.isValid {
        self.showHint("", isValid: true)
      } else {
        self.showHint(model.status.hint, isValid: model.status.isSendAmountValid)
      }
    }
  }
  
  func setupViewEvents() {
    customView.sendView.amountTextField.didUpdateText = { [weak viewModel] in
      viewModel?.didInputAmount($0)
    }

    customView.sendView.maxButton.configuration.action = { [weak viewModel] in
      viewModel?.didTapMax()
    }

    [customView.inputView1, customView.inputView2].forEach {
      $0.didTapChooseToken = { [weak viewModel, weak self] swapField in
        self?.customView.sendView.amountTextField.resignFirstResponder()
        self?.customView.receiveView.amountTextField.resignFirstResponder()
        viewModel?.didTapTokenPicker(swapField: swapField)
      }
    }
  }
}

private extension SwapViewController {

  func showHint(_ hint: String, isValid: Bool) {
    let label = customView.detailsView.statusLabel
    if label.text == nil {
      label.text = hint
      return
    }
    if label.text == hint { return }
    label.textColor = isValid ? .Button.secondaryForeground : .Field.errorBorder
    label.text = hint
    label.bounce()
  }
  
}

