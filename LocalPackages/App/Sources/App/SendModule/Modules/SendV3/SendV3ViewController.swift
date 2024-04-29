import UIKit
import TKUIKit

final class SendV3ViewController: GenericViewViewController<SendV3View>, KeyboardObserving {
  private let viewModel: SendV3ViewModel
  
  init(viewModel: SendV3ViewModel) {
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
    customView.recipientTextField.becomeFirstResponder()
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

private extension SendV3ViewController {
  func setup() {
    title = "Send"
    view.backgroundColor = .Background.page
    
    customView.amountInputView.textInputControl.delegate = viewModel.sendAmountTextFieldFormatter
    
    var configuration = TKButton.Configuration.titleHeaderButtonConfiguration(category: .tertiary)
    configuration.content.title = .plainString("Paste")
    configuration.action = { [weak viewModel] in
      viewModel?.didTapRecipientPasteButton()
    }
    customView.recipientPasteButton.configuration = configuration
    
    configuration.action = { [weak viewModel] in
      viewModel?.didTapCommentPasteButton()
    }
    customView.commentPasteButton.configuration = configuration
    
    var scanConfiguration = TKButton.Configuration.fieldAccentButtonConfiguration()
    scanConfiguration.content.icon = .TKUIKit.Icons.Size28.qrViewFinderThin
    scanConfiguration.padding.left = 8
    scanConfiguration.padding.right = 16
    scanConfiguration.action = { [weak viewModel] in
      viewModel?.didTapRecipientScanButton()
    }
    customView.recipientScanButton.configuration = scanConfiguration
  }
  
  func setupBindings() {
    viewModel.didUpdateModel = { [weak self] model in
      guard let customView = self?.customView else { return }
      
      customView.recipientTextField.placeholder = model.recipient.placeholder
      customView.recipientTextField.text = model.recipient.text
      customView.recipientTextField.isValid = model.recipient.isValid
      
      if let amountModel = model.amount {
        customView.amountInputView.isHidden = false
        customView.amountInputView.amountTextField.placeholder = amountModel.placeholder
        customView.amountInputView.amountTextField.text = amountModel.text
        customView.amountInputView.tokenView.label.text = amountModel.token.title
        customView.amountInputView.tokenView.image = amountModel.token.image
        
      } else {
        customView.amountInputView.isHidden = true
      }
      
      switch model.balance.remaining {
      case .insufficient:
        customView.amountInputView.balanceView.remainingView.isHidden = true
        customView.amountInputView.balanceView.insufficientLabel.isHidden = false
      case .remaining(let value):
        customView.amountInputView.balanceView.remainingView.isHidden = false
        customView.amountInputView.balanceView.insufficientLabel.isHidden = true
        
        customView.amountInputView.balanceView.remainingView.remaining = value
      }
      customView.amountInputView.balanceView.convertedValue = model.balance.converted
    
      customView.commentInputView.commentTextField.placeholder = model.comment.placeholder
      customView.commentInputView.commentTextField.text = model.comment.text
      customView.commentInputView.commentTextField.isValid = model.comment.isValid
      customView.commentInputView.descriptionLabel.attributedText = model.comment.description
      customView.commentInputView.descriptionContainer.isHidden = model.comment.description == nil

      customView.continueButton.configuration.content = TKButton.Configuration.Content(title: .plainString(model.button.title))
      customView.continueButton.configuration.isEnabled = model.button.isEnabled
      customView.continueButton.configuration.showsLoader = model.button.isActivity
      customView.continueButton.configuration.action = model.button.action
    }
  }
  
  func setupViewEvents() {
    customView.recipientTextField.didUpdateText = { [weak viewModel] in
      viewModel?.didInputRecipient($0)
    }
    
    customView.amountInputView.didUpdateText = { [weak viewModel] in
      viewModel?.didInputAmount($0 ?? "")
    }
    
    customView.amountInputView.didTapTokenPicker = { [weak viewModel] in
      viewModel?.didTapWalletTokenPicker()
    }
    
    customView.amountInputView.balanceView.didTapMax = { [weak viewModel] in
      viewModel?.didTapMax()
    }
    
    customView.commentInputView.commentTextField.didUpdateText = { [weak viewModel] in
      viewModel?.didInputComment($0)
    }
  }
}
