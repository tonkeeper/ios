import UIKit
import TKUIKit

final class SendRecipientViewController: GenericViewViewController<SendRecipientView> {
  private let viewModel: SendRecipientViewModel
  
  init(viewModel: SendRecipientViewModel) {
    self.viewModel = viewModel
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    title = "Recipient"
    view.backgroundColor = .Background.page
    
    setup()
    setupBindings()
    setupViewEventsBinding()
    viewModel.viewDidLoad()
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    viewModel.viewWillAppear()
    customView.recipientTextField.becomeFirstResponder()
  }
  
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    viewModel.viewDidAppear()
  }
  
  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    viewModel.viewWillDisappear()
  }
}

private extension SendRecipientViewController {
  func setup() {
    customView.recipientTextField.placeholder = "Address or name"
    
    var pasteButtonConfiguration = TKButton.Configuration.titleHeaderButtonConfiguration(category: .tertiary)
    pasteButtonConfiguration.content.title = .plainString("Paste")
    pasteButtonConfiguration.action = { [weak self] in
      self?.viewModel.didTapPasteButton()
    }
    customView.pasteButton.configuration = pasteButtonConfiguration
  }
  
  func setupBindings() {
    viewModel.didUpdateRecipient = { [weak self] recipient in
      self?.customView.recipientTextField.text = recipient ?? ""
    }
    
    viewModel.didUpdateValidationState = { [weak self] in
      self?.customView.recipientTextField.isValid = $0
    }

    viewModel.didUpdateIsRecipientTextFieldActive = { [weak self] isActive in
      if isActive {
        self?.customView.recipientTextField.becomeFirstResponder()
      } else {
        self?.customView.recipientTextField.resignFirstResponder()
      }
    }
  }
  
  func setupViewEventsBinding() {
    customView.recipientTextField.didUpdateText = { [weak self] text in
      self?.viewModel.didEditRecipient(input: text)
    }
  }
}
