import UIKit
import KeeperCore

protocol SendRecipientModuleOutput: AnyObject {
  var didFinish: ((Recipient) -> Void)? { get set }
  var didUpdateIsNextAvailable: ((Bool) -> Void)? { get set }
}

protocol SendRecipientModuleInput: AnyObject {
  func finish()
}

protocol SendRecipientViewModel: AnyObject {
  var didUpdateRecipient: ((String?) -> Void)? { get set }
  var didUpdateValidationState: ((Bool) -> Void)? { get set }
  var didUpdateIsRecipientTextFieldActive: ((Bool) -> Void)? { get set }
  
  func viewDidLoad()
  func viewDidAppear()
  func viewWillAppear()
  func viewWillDisappear()
  func didEditRecipient(input: String)
  func didTapPasteButton()
}

final class SendRecipientViewModelImplementation: SendRecipientViewModel, SendRecipientModuleOutput, SendRecipientModuleInput {
  
  // MARK: - SendRecipientModuleOutput

  var didFinish: ((Recipient) -> Void)?
  var didUpdateIsNextAvailable: ((Bool) -> Void)?
  
  // MARK: - SendRecipientModuleInput
  
  func finish() {
    guard let recipient = sendRecipientController.getRecipient() else { return }
    didFinish?(recipient)
  }
  
  // MARK: - SendRecipientViewModel
  
  var didUpdateRecipient: ((String?) -> Void)?
  var didUpdateValidationState: ((Bool) -> Void)?
  var didUpdateIsRecipientTextFieldActive: ((Bool) -> Void)?
  
  func viewDidLoad() {
    sendRecipientController.didUpdateRecipient = { [weak self] in
      guard let self = self else { return }
      Task { @MainActor in
        self.didUpdateRecipient?(self.sendRecipientController.getRecipientValue())
      }
    }
    sendRecipientController.didUpdateIsValid = { [weak self] isValid in
      guard let self else { return }
      Task { @MainActor in
        self.didUpdateValidationState?(isValid)
      }
    }
    
    sendRecipientController.didUpdateIsReadyToContinue = { [weak self] isContinueEnable in
      guard let self else { return }
      Task { @MainActor in
        self.isContinueEnabled = isContinueEnable
      }
    }
    
    sendRecipientController.start()
  }
  
  func viewWillAppear() {}
  
  func viewDidAppear() {
    didUpdateIsNextAvailable?(isContinueEnabled)
  }
  
  func viewWillDisappear() {}

  func didEditRecipient(input: String) {
    sendRecipientController.didUpdateRecipientInput(input)
  }
  
  func didTapPasteButton() {
    guard let pasteboardString = UIPasteboard.general.string else { return }
    didUpdateRecipient?(pasteboardString)
    sendRecipientController.didUpdateRecipientInput(pasteboardString)
  }

  // MARK: - State
  
  private var isContinueEnabled: Bool = false {
    didSet {
      didUpdateIsNextAvailable?(isContinueEnabled)
    }
  }
  
  // MARK: - Dependencies
  
  private let sendRecipientController: SendRecipientController
  
  // MARK: - Init
  
  init(sendRecipientController: SendRecipientController) {
    self.sendRecipientController = sendRecipientController
  }
}

private extension SendRecipientViewModelImplementation {}
