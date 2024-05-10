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
    // customView.recipientTextField.becomeFirstResponder()
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
    view.backgroundColor = .Background.page
  }
  
  func setupBindings() {
    viewModel.didUpdateModel = { [weak self] model in
      guard let customView = self?.customView else { return }
      
      // customView.someView = model.field
    }
  }
  
  func setupViewEvents() {
//    customView.recipientTextField.didUpdateText = { [weak viewModel] in
//      viewModel?.didInputRecipient($0)
//    }
  }
}

