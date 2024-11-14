import UIKit
import TKUIKit
import TKLocalize
import KeeperCore

protocol RecipientInputModuleOutput: AnyObject {
  var didResolveRecipient: ((Recipient?) -> Void)? { get set }
}

final class RecipientInputViewController: UIViewController, RecipientInputModuleOutput {
  
  private enum State {
    case none
    case resolving
    case failed
    case success(Recipient)
  }
  
  private(set) var isInputEditing: Bool = false
  
  var didResolveRecipient: ((Recipient?) -> Void)?
  
  var didUpdateText: (() -> Void)?
  
  lazy var recipientTextInputControl: TKTextInputTextViewControl = {
    let textInputControl = TKTextInputTextViewControl()
    return textInputControl
  }()
  
  lazy var recipientTextField: TKTextField = {
    return TKTextField(
      textFieldInputView: TKTextFieldInputView(
        textInputControl: recipientTextInputControl
      )
    )
  }()
  let recipientPasteButton = TKButton()
  let loaderView = TKLoaderView(size: .small, style: .primary)
  
  private var resolvingState: State = .none {
    didSet {
      didUpdateResolveState()
      switch resolvingState {
      case .success(let recipient):
        didResolveRecipient?(recipient)
      default:
        didResolveRecipient?(nil)
      }
    }
  }
  private var resolvingTask: Task<Void, Never>?
  
  private let wallet: Wallet
  private let recipientResolver: RecipientResolver
  
  init(wallet: Wallet,
       recipientResolver: RecipientResolver) {
    self.wallet = wallet
    self.recipientResolver = recipientResolver
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    setup()
  }
  
  func endEditing() {
    recipientTextField.resignFirstResponder()
  }
  
  private func setup() {
    recipientTextInputControl.autocorrectionType = .no
    recipientTextInputControl.returnKeyType = .done
    recipientTextField.placeholder = TKLocales.Send.Recepient.placeholder
    recipientTextField.didBeginEditing = { [weak self] in
      self?.isInputEditing = true
    }
    recipientTextField.didEndEditing = { [weak self] in
      guard let self else { return }
      self.isInputEditing = false
    }
    recipientTextField.didUpdateText = { [weak self] text in
      self?.recipientTextField.isValid = true
      self?.resolve(text: text)
      self?.didUpdateText?()
    }
    updateTextFieldRightItems()

    var configuration = TKButton.Configuration.titleHeaderButtonConfiguration(category: .tertiary)
    configuration.content.title = .plainString(TKLocales.Actions.paste)
    configuration.action = { [weak self] in
      guard let pasteboardString = UIPasteboard.general.string else { return }
      self?.recipientTextField.text = pasteboardString
      self?.recipientTextField.resignFirstResponder()
      self?.resolve(text: pasteboardString)
      self?.didUpdateText?()
    }
    recipientPasteButton.configuration = configuration

    view.addSubview(recipientTextField)
    recipientTextField.snp.makeConstraints { make in
      make.edges.equalTo(self.view)
    }
  }
  
  private func resolve(text: String?) {
    if let resolvingTask {
      resolvingTask.cancel()
    }
    
    resolvingState = .none
    guard let text, !text.isEmpty else {
      return
    }

    resolvingTask = Task { @MainActor [weak self] in
      guard let self else { return }
      try? await Task.sleep(nanoseconds: 500_000_000)
      guard !Task.isCancelled else { return }
      self.resolvingState = .resolving
      do {
        let recipient = try await self.recipientResolver.resolverRecipient(string: text, isTestnet: wallet.isTestnet)
        self.resolvingState = .success(recipient)
      } catch {
        self.resolvingState = .failed
      }
    }
  }
  
  private func didUpdateResolveState() {
    switch resolvingState {
    case .none:
      recipientTextField.isValid = true
    case .success:
      recipientTextField.isValid = true
    case .failed:
      recipientTextField.isValid = false
    case .resolving:
      recipientTextField.isValid = true
    }
    updateTextFieldRightItems()
  }
  
  private func updateTextFieldRightItems() {
    var rightItems = [TKTextField.RightItem]()
    rightItems.append(TKTextField.RightItem(view: recipientPasteButton, mode: .empty))
    switch resolvingState {
    case .resolving:
      rightItems.append(
        TKTextField.RightItem(
          view: loaderView,
          mode: .nonEmpty,
          padding: UIEdgeInsets(
            top: 0,
            left: 2,
            bottom: 0,
            right: 18
          )
        )
      )
    default: break
    }

    recipientTextField.rightItems = rightItems
  }
}

extension RecipientInputViewController: UITextViewDelegate {
  func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
    if (text == "\n"){
      textView.resignFirstResponder()
      return false
    }
    return true
  }
}
