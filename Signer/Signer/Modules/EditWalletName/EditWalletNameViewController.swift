import UIKit
import TKUIKit

final class EditWalletNameViewController: GenericViewViewController<EditWalletNameView>, KeyboardObserving {
  enum PresentationMode {
    case sheet
    case fullscreen
    
    var navigationBarBottomPadding: CGFloat {
      switch self {
      case .fullscreen:
        return 44
      case .sheet:
        return 0
      }
    }
  }
  
  var presentationMode: PresentationMode = .fullscreen {
    didSet {
      customView.titleDescriptionViewTopPadding = presentationMode.navigationBarBottomPadding
    }
  }
  
  private let viewModel: EditWalletNameViewModel
  
  init(viewModel: EditWalletNameViewModel) {
    self.viewModel = viewModel
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    customView.walletNameInputControl.delegate = self
    customView.titleDescriptionViewTopPadding = presentationMode.navigationBarBottomPadding
    setupBinding()
    viewModel.viewDidLoad()
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    registerForKeyboardEvents()
    customView.walletNameTextField.becomeFirstResponder()
  }
  
  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    unregisterFromKeyboardEvents()
  }
  
  func keyboardWillShow(_ notification: Notification) {
    guard let keyboardSize = notification.keyboardSize,
          let duration = notification.keyboardAnimationDuration,
          let curve = notification.keyboardAnimationCurve else { return }
    customView.updateKeyboardHeight(keyboardSize.height,
                                    duration: duration,
                                    curve: curve)
  }
  
  func keyboardWillHide(_ notification: Notification) {
    guard let duration = notification.keyboardAnimationDuration,
          let curve = notification.keyboardAnimationCurve else { return }
    customView.hideKeyboard(duration: duration, curve: curve)
  }
}

private extension EditWalletNameViewController {
  func setupBinding() {
    viewModel.didUpdateTitleDescription = { [customView] model in
      customView.titleDescriptionView.configure(model: model)
    }
    viewModel.didUpdateWalletNameTextFieldPlaceholder = { [customView] placeholder in
      customView.walletNameTextField.placeholder = placeholder
    }
    viewModel.didUpdateWalletNameTextFieldValue = { [customView] value in
      customView.walletNameTextField.text = value ?? ""
    }
    viewModel.didUpdateContinueButton = { [customView] configuration in
      customView.continueButton.configuration = configuration
    }
    viewModel.didUpdateIsContinueButtonEnabled = { [customView] isEnabled in
      customView.continueButton.isEnabled = isEnabled
    }

    customView.walletNameTextField.didUpdateText = { [viewModel] input in
      viewModel.didUpdateInput(input)
    }
  }
}

extension EditWalletNameViewController: UITextFieldDelegate {
  func textField(_ textField: UITextField,
                 shouldChangeCharactersIn range: NSRange,
                 replacementString string: String) -> Bool {
    let maxLength = 24
    let currentString = (textField.text ?? "") as NSString
    let newString = currentString.replacingCharacters(in: range, with: string)
    
    return newString.count <= maxLength
  }
}
