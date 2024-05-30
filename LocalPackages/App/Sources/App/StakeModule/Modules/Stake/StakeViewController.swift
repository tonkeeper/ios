import UIKit
import TKUIKit

final class StakeViewController: ModalViewController<StakeView, ModalNavigationBarView>, KeyboardObserving {
  
  private var isViewDidAppearFirstTime = false
  
  // MARK: - Dependencies
  
  private let viewModel: StakeViewModel
  
  // MARK: - Init
  
  init(viewModel: StakeViewModel) {
    self.viewModel = viewModel
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  deinit {
    print("\(Self.self) deinit")
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
  
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    if !isViewDidAppearFirstTime {
      isViewDidAppearFirstTime = true
      Task { @MainActor in customView.amountInputView.inputControl.amountTextField.becomeFirstResponder() }
    }
  }
  
  public override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    unregisterFromKeyboardEvents()
  }
  
  override func setupNavigationBarView() {
    super.setupNavigationBarView()
    
    customView.scrollView.contentInset.top = ModalNavigationBarView.defaultHeight
    
    customNavigationBarView.setupLeftBarItem(
      configuration: ModalNavigationBarView.BarItemConfiguration(
        view: customView.stakeInfoButton,
        contentAlignment: .center
      )
    )
    
    customNavigationBarView.setupCenterBarItem(
      configuration: ModalNavigationBarView.BarItemConfiguration(
        view: customView.titleView
      )
    )
  }
  
  public func keyboardWillShow(_ notification: Notification) {
    guard let animationDuration = notification.keyboardAnimationDuration else { return }
    guard let keyboardHeight = notification.keyboardSize?.height else { return }
    
    let contentInsetBottom = keyboardHeight + customView.continueButtonContainer.bounds.height - view.safeAreaInsets.bottom
    let buttonContainerTranslatedY = -keyboardHeight + view.safeAreaInsets.bottom
    
    UIView.animate(withDuration: animationDuration, delay: 0, options: .curveEaseInOut) {
      self.customView.scrollView.contentInset.bottom = contentInsetBottom
      self.customView.continueButtonContainer.transform = CGAffineTransform(translationX: 0, y: buttonContainerTranslatedY)
    }
  }
  
  public func keyboardWillHide(_ notification: Notification) {
    guard let animationDuration = notification.keyboardAnimationDuration else { return }
    
    UIView.animate(withDuration: animationDuration, delay: 0, options: .curveEaseInOut) {
      self.customView.scrollView.contentInset.bottom = 0
      self.customView.continueButtonContainer.transform = .identity
    }
  }
}

// MARK: - Setup

private extension StakeViewController {
  func setup() {
    view.backgroundColor = .Background.page
    customView.backgroundColor = .Background.page
    
    customView.amountInputView.inputControl.amountTextField.delegate = viewModel.textFieldFormatter
  }
  
  func setupBindings() {
    viewModel.didUpdateModel = { [weak customView] model in
      customView?.configure(model: model)
    }
    
    viewModel.didUpdateInputAmountText = { [weak customView] text in
      guard text != customView?.amountInputView.inputControl.amountTextField.text else { return }
      customView?.amountInputView.inputControl.setInputValue(text)
    }
    
    viewModel.didUpdateAvailableTitle = { [weak customView] availableTitle in
      customView?.footerView.descriptionLabel.attributedText = availableTitle
    }
    
    viewModel.didUpdateSelectedPool = { [weak customView] selectedPoolContainerModel in
      customView?.selectedPoolContainer.configure(model: selectedPoolContainerModel)
    }
  }
  
  func setupViewEvents() {
    customView.amountInputView.inputControl.didUpdateText = { [weak viewModel] text in
      guard let text else { return }
      viewModel?.didInputAmount(text)
    }
    
    customView.amountInputView.didTapConvertedButton = { [weak viewModel] in
      viewModel?.didTapConvertedButton()
    }
  }
}
