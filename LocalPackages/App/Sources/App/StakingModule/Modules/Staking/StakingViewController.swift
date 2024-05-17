import UIKit
import TKUIKit
import TKCore

final class StakingViewController: GenericViewViewController<StakingView>, KeyboardObserving {
  private let viewModel: StakingViewModel
  private let amountInputViewController = AmountInputViewController()
  
  init(viewModel: StakingViewModel) {
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
    customView.becomeFirstResponder()
  }

  override func viewWillDisappear(_ animated: Bool) {
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
      self.customView.scrollView.contentInset.bottom = .zero
    }
  }
}

private extension StakingViewController {
  func setup() {
    title = .moduleTitle
    addChild(amountInputViewController)
    customView.embedAmountInputView(amountInputViewController.view)
    amountInputViewController.didMove(toParent: self)
    amountInputViewController.isTokenPickerAvailable = false
    
    customView.stakingBalanceView.button.configuration = makeMaxButtonConfiguration(
      action: { [weak customView, weak viewModel] in
        customView?.stakingBalanceView.button.isSelected.toggle()
        viewModel?.didToggleMaxAmount()
      }
    )
    
    customView.providerView.addAction(
      UIAction(
        handler: { [weak viewModel] _ in
          viewModel?.didTapProvider()
        }
      ),
      for: .touchUpInside
    )
    
    customView.continueButton.configuration.content = TKButton.Configuration.Content(title: .plainString(.continueButtonTitle))
    customView.continueButton.configuration.action = { [weak viewModel] in
      viewModel?.didTapContinueButton()
    }
  }
  
  func setupBindings() {
    viewModel.didUpdateInputValue = { [weak self] value in
      self?.amountInputViewController.inputValue = value ?? ""
    }
    
    viewModel.didUpdateInputSymbol = { [weak self] symbol in
      self?.amountInputViewController.inputSymbol = symbol ?? ""
    }
    
    viewModel.didUpdateConvertedValue = { [weak self] value in
      self?.amountInputViewController.convertedValue = value
    }
    
    viewModel.didUpdateMaximumFractionDigits = { [weak self] fractionDigits in
      self?.amountInputViewController.maximumFractionDigits = fractionDigits
    }
    
    viewModel.didUpdateRemaining = { [weak self] value in
      self?.customView.stakingBalanceView.label.attributedText = value
    }
    
    viewModel.didUpdateProvider = { [weak self] model in
      self?.customView.providerView.configure(model: model)
    }
    
    viewModel.didUpdateIsContinueEnabled = { [weak self] value in 
      self?.customView.continueButton.configuration.isEnabled = value
    }
    
    viewModel.didUpdateSwapIcon = { [weak self] isHidden in
      let image: UIImage? = isHidden ? nil : .TKUIKit.Icons.Size16.swapVertical
      self?.amountInputViewController.convertedIcon = image
    }
    
    viewModel.didResetHighlightIsMax = { [weak self] in
      self?.customView.stakingBalanceView.button.isSelected = false
    }
  }
  
  func setupViewEvents() {
    amountInputViewController.didUpdateText = { [weak viewModel] text in
      viewModel?.didEditAmountInput(text)
    }
    
    amountInputViewController.didToggle = { [weak viewModel] in
      viewModel?.didToggleInputMode()
    }
  }
  
  func makeMaxButtonConfiguration(action: @escaping  (() -> Void)) -> TKButton.Configuration {
    var configuration = TKButton.Configuration.titleHeaderButtonConfiguration(category: .secondary)
    configuration.backgroundColors[.selected] = .Button.primaryBackground
    configuration.content.title = .plainString(.maxButtonTitle)
    configuration.action = action
    
    return configuration
  }
}

private extension String {
  static let maxButtonTitle = "MAX"
  static let moduleTitle = "Stake"
  static let continueButtonTitle = "Continue"
}
