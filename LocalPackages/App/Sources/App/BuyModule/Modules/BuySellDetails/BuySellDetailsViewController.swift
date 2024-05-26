import UIKit
import TKUIKit

final class BuySellDetailsViewController: ModalViewController<BuySellDetailsView, ModalNavigationBarView>, KeyboardObserving {
  
  private lazy var tapGestureRecognizer: UITapGestureRecognizer = {
    let gestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(resignGestureAction))
    gestureRecognizer.cancelsTouchesInView = false
    return gestureRecognizer
  }()
  
  // MARK: - Dependencies
  
  private let viewModel: BuySellDetailsViewModel
  
  // MARK: - Init
  
  init(viewModel: BuySellDetailsViewModel) {
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
    setupGestures()
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
  
  override func setupNavigationBarView() {
    super.setupNavigationBarView()
    customView.scrollView.contentInset.top = ModalNavigationBarView.defaultHeight
  }
  
  public func keyboardWillShow(_ notification: Notification) {
    guard let animationDuration = notification.keyboardAnimationDuration else { return }
    guard let keyboardHeight = notification.keyboardSize?.height else { return }
    
    let contentInsetBottom = keyboardHeight + customView.continueButtonContainer.bounds.height - view.safeAreaInsets.bottom
    let buttonContainerTranslatedY = -keyboardHeight + view.safeAreaInsets.bottom + .continueButtonBottomOffset
    
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

private extension BuySellDetailsViewController {
  func setup() {
    view.backgroundColor = .Background.page
    customView.backgroundColor = .Background.page
    
    customView.payAmountInputControl.formatterDelegate = viewModel.payAmountTextFieldFormatter
    customView.getAmountInputControl.formatterDelegate = viewModel.getAmountTextFieldFormatter
    
    customView.payAmountInputView.didInputText("0", animateTextActions: false)
    customView.getAmountInputView.didInputText("0", animateTextActions: false)
  }
  
  func setupBindings() {
    viewModel.didUpdateModel = { [weak customView] model in
      customView?.configure(model: model)
    }
    
    viewModel.didUpdateAmountPay = { [weak customView] text in
      guard customView?.payAmountTextField.text != text else { return }
      customView?.payAmountTextField.text = text
    }
    
    viewModel.didUpdateAmountGet = { [weak customView] text in
      guard customView?.getAmountTextField.text != text else { return }
      customView?.getAmountTextField.text = text
    }
    
    viewModel.didUpdateIsTokenAmountValid = { [weak self] isTokenAmountValid in
      self?.updateActiveTextFieldState(isInputValid: isTokenAmountValid)
    }
    
    viewModel.didUpdateRateContainerModel = { [weak customView] rateContainerModel in
      customView?.rateContainerView.configure(model: rateContainerModel)
    }
    
    viewModel.didUpdateContinueButtonModel = { [weak customView] model in
      customView?.continueButton.configuration.content.title = .plainString(model.title)
      customView?.continueButton.configuration.isEnabled = model.isEnabled
      customView?.continueButton.configuration.showsLoader = model.isActivity
      customView?.continueButton.configuration.action = model.action
    }
  }
  
  func setupGestures() {
    customView.addGestureRecognizer(tapGestureRecognizer)
  }
  
  func setupViewEvents() {
    customView.payAmountTextField.didUpdateText = { [weak self] text in
      self?.viewModel.didInputAmountPay(text)
    }
    
    customView.getAmountTextField.didUpdateText = { [weak self] text in
      self?.viewModel.didInputAmountGet(text)
    }
  }
  
  func updateActiveTextFieldState(isInputValid: Bool) {
    if customView.payAmountTextField.isActive {
      updateTextFieldState(isValid: isInputValid, for: customView.payAmountTextField)
    } else if customView.getAmountTextField.isActive {
      updateTextFieldState(isValid: isInputValid, for: customView.getAmountTextField)
    }
  }
  
  func updateTextFieldState(isValid: Bool, for textField: TKTextField) {
    let textFieldState = textField.textFieldState
    let newState: TKTextFieldState
    switch (textFieldState, isValid) {
    case (_, true):
      newState = textField.isActive ? .active : .inactive
    case (_, false):
      newState = textFieldState == .inactive ? .inactive : .error
    }
    guard textField.textFieldState != newState else { return }
    textField.textFieldState = newState
  }
  
  @objc func resignGestureAction(sender: UITapGestureRecognizer) {
    let touchLocation = sender.location(in: customView.contentStackView)
    let isTapInPayTextField = customView.payAmountTextField.frame.contains(touchLocation)
    let isTapInGetTextField = customView.getAmountTextField.frame.contains(touchLocation)
    let isTapInTextFields = isTapInPayTextField || isTapInGetTextField
    
    guard !isTapInTextFields else { return }
    
    customView.payAmountTextField.resignFirstResponder()
    customView.getAmountTextField.resignFirstResponder()
  }
}

private extension CGFloat {
  static let continueButtonBottomOffset: CGFloat = 56
}
