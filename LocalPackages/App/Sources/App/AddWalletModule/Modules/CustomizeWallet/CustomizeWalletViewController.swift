import UIKit
import TKUIKit

final class CustomizeWalletViewController: GenericViewViewController<CustomizeWalletView>, KeyboardObserving {
  private let viewModel: CustomizeWalletViewModel
  
  lazy var tapGestureRecognizer: UITapGestureRecognizer = {
    let gestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(resignGestureAction))
    gestureRecognizer.isEnabled = false
    return gestureRecognizer
  }()
  
  init(viewModel: CustomizeWalletViewModel) {
    self.viewModel = viewModel
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    setupBindings()
    setupGestures()
    setupViewActions()
    viewModel.viewDidLoad()
  }
  
  public override func viewWillAppear(_ animated: Bool) {
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
      self.customView.colorPickerView.alpha = 0.32
      self.customView.iconPickerView.alpha = 0.32
    }
  }
  
  public func keyboardWillHide(_ notification: Notification) {
    guard let animationDuration = notification.keyboardAnimationDuration else { return }
    UIView.animate(withDuration: animationDuration, delay: 0, options: .curveEaseInOut) {
      self.customView.keyboardHeight = 0
      self.customView.colorPickerView.alpha = 1
      self.customView.iconPickerView.alpha = 1
    }
  }
}

private extension CustomizeWalletViewController {
  func setupBindings() {
    viewModel.didUpdateModel = { [weak customView] model in
      customView?.configure(model: model)
    }
    
    viewModel.didSelectWalletIcon = { [weak customView] icon in
      customView?.badgeView.icon = icon
    }
    
    viewModel.didSelectColor = { [weak customView] color in
      customView?.badgeView.color = color
    }
    
    viewModel.didUpdateContinueButtonIsEnabled = { [weak customView] isEnabled in
      customView?.continueButton.isEnabled = isEnabled
    }
    
    viewModel.didUpdateContinueButtonIsLoadig = { [weak customView] isLoading in
      customView?.continueButton.configuration.showsLoader = isLoading
    }
  }
  
  func setupGestures() {
    customView.contentStackView.addGestureRecognizer(tapGestureRecognizer)
  }
  
  func setupViewActions() {
    customView.walletNameTextField.didBeginEditing = { [weak self] in
      self?.customView.colorPickerView.isUserInteractionEnabled = false
      self?.customView.iconPickerView.isUserInteractionEnabled = false
      self?.tapGestureRecognizer.isEnabled = true
    }
    
    customView.walletNameTextField.didEndEditing = { [weak self] in
      self?.customView.colorPickerView.isUserInteractionEnabled = true
      self?.customView.iconPickerView.isUserInteractionEnabled = true
      self?.tapGestureRecognizer.isEnabled = false
    }
    
    customView.walletNameTextField.didUpdateText = { [weak self] in
      self?.viewModel.setWalletName($0)
    }
    
    customView.iconPickerView.didSelectIcon = { [weak self] in
      self?.viewModel.setIcon($0)
    }
  }
  
  @objc func resignGestureAction() {
    customView.walletNameTextField.resignFirstResponder()
  }
}
