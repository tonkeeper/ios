import UIKit
import TKUIKit
import TKLocalize

final class SwapViewController: GenericViewViewController<SwapView>, KeyboardObserving {
  private let viewModel: SwapViewModel
  private var delayedExpand: DispatchWorkItem?
  
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
    customView.sendView.amountTextField.becomeFirstResponder()
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    registerForKeyboardEvents()
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

    customView.continueButton.configuration.content = TKButton.Configuration.Content(title: .plainString("Continue"))
  }

  func setupSwapInputs() {
    customView.swapInputsButton.configuration.action = { [weak self] in
      guard let self else { return }

      self.customView.inputView1.swapField.inverse()
      self.customView.inputView2.swapField.inverse()

      [self.customView.inputView1, self.customView.inputView2].forEach { inputView in
        inputView.snp.updateConstraints { make in
          make.top.equalTo(inputView.swapField == .send ? SwapView.sendViewTop : SwapView.receiveViewTop)
        }
      }
      UIView.spring(damping: 0.75, velocity: 0.25) {
        self.customView.layoutIfNeeded()
      } completion: { _ in
        self.viewModel.swapTokens()
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
      self.customView.receiveView.amountTextField.isEnabled = model.status.isValidReceiveToken
      
      self.customView.swapInputsButton.isEnabled = model.status.isValidReceiveToken

      if model.status.isValid {
        self.customView.detailsView.update(items: model.swapDetails, oneTokenPrice: model.oneTokenPrice)
        self.customView.sendView.resignFirstResponder()
        self.customView.showLoading()
        self.customView.continueButton.isEnabled = true
        // TODO: - Add logic of retrieving swap providers
        // Add API integration, otherwise no pause for showing extra loader needed
        
        self.delayedExpand?.cancel()
        self.delayedExpand = DispatchWorkItem { [weak self] in
          self?.customView.expandDetailView()
        }
        if let item = self.delayedExpand {
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: item)
        }
      } else {
        if model.receive.token != nil {
          self.delayedExpand?.cancel()
          self.customView.collapseDetailView(showLoader: false)
        }
        self.customView.continueButton.isEnabled = false
        self.showHint(model.status.hint, isValid: model.status.isSendAmountValid)
      }
    }
    viewModel.shoudMakeActive = { [weak self] field in
      switch field {
      case .send:
        self?.customView.sendView.amountTextField.becomeFirstResponder()
      case .receive:
        self?.customView.receiveView.amountTextField.becomeFirstResponder()
      }
    }
    viewModel.shouldReloadProvider = { [weak self] in
      self?.customView.collapseDetailView()
    }
  }
  
  func setupViewEvents() {
    customView.sendView.amountTextField.didUpdateText = { [weak viewModel] in
      viewModel?.didInputAmount($0, swapField: .send)
    }

    customView.receiveView.amountTextField.didUpdateText = { [weak viewModel] in
      viewModel?.didInputAmount($0, swapField: .receive)
    }

    [customView.inputView1, customView.inputView2].forEach {
      $0.maxButton.configuration.action = { [weak viewModel] in
        viewModel?.didTapMax()
      }
    }

    [customView.inputView1, customView.inputView2].forEach {
      $0.didTapChooseToken = { [weak viewModel, weak self] swapField in
        self?.customView.sendView.amountTextField.resignFirstResponder()
        self?.customView.receiveView.amountTextField.resignFirstResponder()
        viewModel?.didTapTokenPicker(swapField: swapField)
      }
    }
    customView.continueButton.configuration.action = { [weak viewModel] in
      viewModel?.didTapContinue()
    }
  }
}

private extension SwapViewController {

  func showHint(_ hint: String, isValid: Bool) {
    let label = customView.detailsView.statusLabel
    customView.detailsView.loader.stopAnimation()
    UIView.animate(withDuration: 0.2) {
      label.alpha = 1
      self.customView.detailsView.loader.alpha = 0
    }
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

