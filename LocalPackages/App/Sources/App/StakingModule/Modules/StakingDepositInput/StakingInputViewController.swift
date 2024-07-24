import UIKit
import TKUIKit

final class StakingInputViewController: GenericViewViewController<StakingInputView>, KeyboardObserving {
  private let viewModel: StakingInputViewModel
  private let amountInputViewController = AmountInputViewController()
  
  init(viewModel: StakingInputViewModel) {
    self.viewModel = viewModel
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    setup()
    setupViewEvents()
    setupBindings()
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

private extension StakingInputViewController {

  func setup() {
    addChild(amountInputViewController)
    customView.setAmountInputView(amountInputViewController.customView)
    amountInputViewController.didMove(toParent: self)
    amountInputViewController.isTokenPickerAvailable = false
    
    customView.balanceView.maxButton.configuration = createMaxButtonConfiguration()
  }
  
  func setupBindings() {
    viewModel.didUpdateTitle = { [weak self] title in
      self?.title = title
    }
    
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
      guard let self else { return }
      self.customView.balanceView.balanceLabel.attributedText = value
    }
    
    viewModel.didUpdatePoolInfoView = { [weak self] model in
      if let model {
        self?.customView.infoViewContainer.isHidden = false
        self?.customView.infoView.configure(model: model)
      } else {
        self?.customView.infoViewContainer.isHidden = true
      }
    }

    viewModel.didUpdateButton = { [weak self] title, isEnable in
      self?.customView.continueButton.configuration.content.title = .plainString(title)
      self?.customView.continueButton.isEnabled = isEnable
    }
    
    viewModel.didUpdateSwapIcon = { [weak self] isHidden in
      let image: UIImage? = isHidden ? nil : .TKUIKit.Icons.Size16.swapVertical
      self?.amountInputViewController.convertedIcon = image
    }
    
    viewModel.didUpdateIsMax = { [weak self] in
      self?.customView.balanceView.maxButton.isSelected = $0
    }
  }
  
  func setupViewEvents() {
    amountInputViewController.didUpdateText = { [weak viewModel] text in
      viewModel?.didEditAmountInput(text ?? "")
    }
    
    amountInputViewController.didToggle = { [weak viewModel] in
      viewModel?.didToggleInputMode()
    }
    
    customView.infoView.addAction(UIAction(handler: { [weak viewModel] _ in
      viewModel?.didTapInfoView()
    }), for: .touchUpInside)
  }
  
  func createMaxButtonConfiguration() -> TKButton.Configuration {
    let configuration = TKButton.Configuration(
      content: TKButton.Configuration.Content(title: .plainString(.maxButtonTitle)),
      contentPadding: UIEdgeInsets(top: 6, left: 16, bottom: 6, right: 16),
      padding: UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0),
      textStyle: .label2,
      textColor: .Button.secondaryForeground,
      backgroundColors: [
        .normal: .Button.secondaryBackground,
        .highlighted: .Button.secondaryBackgroundHighlighted,
        .disabled: .Button.secondaryBackgroundDisabled,
        .selected: .Button.primaryBackground
      ],
      cornerRadius: 16,
      action: { [weak customView, weak viewModel] in
        customView?.balanceView.maxButton.isSelected.toggle()
        viewModel?.didToggleIsMax()
      }
    )
    return configuration
  }
}

private extension String {
  static let maxButtonTitle = "MAX"
}
