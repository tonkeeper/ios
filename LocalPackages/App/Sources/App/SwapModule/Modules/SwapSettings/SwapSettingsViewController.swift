import UIKit
import TKUIKit

final class SwapSettingsViewController: ModalViewController<SwapSettingsView, ModalNavigationBarView>, KeyboardObserving {
  
  private lazy var tapGestureRecognizer: UITapGestureRecognizer = {
    let gestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(resignGestureAction))
    gestureRecognizer.cancelsTouchesInView = false
    gestureRecognizer.delegate = self
    return gestureRecognizer
  }()
  
  // MARK: - Dependencies
  
  private let viewModel: SwapSettingsViewModel
  
  // MARK: - Init
  
  init(viewModel: SwapSettingsViewModel) {
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
    
    customNavigationBarView.leftItemPadding = 16
    customNavigationBarView.setupLeftBarItem(
      configuration: ModalNavigationBarView.BarItemConfiguration(
        view: customView.titleView,
        contentAlignment: .left
      )
    )
  }
  
  public func keyboardWillShow(_ notification: Notification) {
    guard let animationDuration = notification.keyboardAnimationDuration else { return }
    guard let keyboardHeight = notification.keyboardSize?.height else { return }
    
    let contentInsetBottom = keyboardHeight + customView.saveButtonContainer.bounds.height
    let buttonContainerTranslatedY = -keyboardHeight + view.safeAreaInsets.bottom
    
    UIView.animate(withDuration: animationDuration, delay: 0, options: .curveEaseInOut) {
      self.customView.scrollView.contentInset.bottom = contentInsetBottom
      self.customView.saveButtonContainer.transform = CGAffineTransform(translationX: 0, y: buttonContainerTranslatedY)
    }
  }
  
  public func keyboardWillHide(_ notification: Notification) {
    guard let animationDuration = notification.keyboardAnimationDuration else { return }
    
    UIView.animate(withDuration: animationDuration, delay: 0, options: .curveEaseInOut) {
      self.customView.scrollView.contentInset.bottom = 0
      self.customView.saveButtonContainer.transform = .identity
    }
  }
  
  func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
    guard !(touch.view is TKButton) else { return false }
    guard !(touch.view is TKTextField) else { return false }
    guard !(touch.view is TKTextFieldInputView) else { return false }
    return true
  }
  
  @objc func resignGestureAction(sender: UITapGestureRecognizer) {
    view.endEditing(true)
  }
}

// MARK: - Setup

private extension SwapSettingsViewController {
  func setup() {
    view.backgroundColor = .Background.page
    customView.backgroundColor = .Background.page
    customView.slippageInputContainer.customSlippageInputControl.formatterDelegate = viewModel.slippagePercentageTextFormatter
  }
  
  func setupBindings() {
    viewModel.didUpdateModel = { [weak customView] model in
      customView?.configure(model: model)
    }
    
    viewModel.didUpdateSlippageState = { [weak customView] slippageState in
      customView?.slippageInputContainer.slippageState = slippageState
    }
  }
  
  func setupGestures() {
    customView.contentView.addGestureRecognizer(tapGestureRecognizer)
  }
}
