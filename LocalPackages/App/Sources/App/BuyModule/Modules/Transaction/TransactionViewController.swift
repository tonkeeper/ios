import UIKit
import TKUIKit
import KeeperCore
import TKLocalize

class TransactionViewController: GenericViewViewController<TransactionView>, KeyboardObserving {
  private let viewModel: TransactionViewModel
    
  // MARK: - Init

  init(viewModel: TransactionViewModel) {
    self.viewModel = viewModel
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  // MARK: - View Life cycle

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
  }

  public override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    unregisterFromKeyboardEvents()
  }
  
  public func keyboardWillShow(_ notification: Notification) {
    guard let animationDuration = notification.keyboardAnimationDuration,
    let keyboardHeight = notification.keyboardSize?.height else { return }
    UIView.animate(withDuration: animationDuration, delay: 0, options: .curveEaseInOut) {
      self.customView.keyboardHeight = keyboardHeight
      self.customView.layoutIfNeeded()
    }
  }
  
  public func keyboardWillHide(_ notification: Notification) {
    guard let animationDuration = notification.keyboardAnimationDuration else { return }
    UIView.animate(withDuration: animationDuration, delay: 0, options: .curveEaseInOut) {
      self.customView.keyboardHeight = 0
      self.customView.layoutIfNeeded()
    }
  }
}

private extension TransactionViewController {
  func setup() {
    var continueButtonConfiguration = TKButton.Configuration.actionButtonConfiguration(
      category: .primary,
      size: .large
    )
    continueButtonConfiguration.content.title = .plainString(TKLocales.Actions.continue_action)
    customView.continueButton.configuration = continueButtonConfiguration
  }
  
  func setupBindings() {
    viewModel.didUpdateModel = { [weak self] model in
      guard let self else { return }
      
      customView.configure(model: model)
    }
  }
  
  func setupViewEvents() {
    customView.payTextField.didUpdateText = { [weak viewModel] text in
      viewModel?.didInputPayAmount(text)
    }
    
    customView.getTextField.didUpdateText = { [weak viewModel] text in
      viewModel?.didInputGetAmount(text)
    }
    
    customView.continueButton.configuration.action = { [weak viewModel] in
      viewModel?.didTapContinueButton()
    }
  }
}
