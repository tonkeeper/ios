import UIKit
import KeeperCore

protocol SendCommentModuleOutput: AnyObject {
  var didFinish: ((String?) -> Void)? { get set }
  var didUpdateIsContinueEnable: ((Bool) -> Void)? { get set }
}

protocol SendCommentModuleInput: AnyObject {
  func finish()
}

protocol SendCommentViewModel: AnyObject {
  var didUpdateComment: ((String) -> Void)? { get set }
  var didUpdatePlaceholder: ((String) -> Void)? { get set }
  var didUpdateDescription: ((NSAttributedString) -> Void)? { get set }
  var didUpdateDescriptionVisibility: ((Bool) -> Void)? { get set }
  
  func viewDidLoad()
  func viewDidAppear()
  func viewWillDisappear()
  func didEditComment(_ comment: String)
  func didTapPasteButton()
}

final class SendCommentViewModelImplementation: SendCommentViewModel, SendCommentModuleOutput, SendCommentModuleInput {
  
  // MARK: - SendCommentModuleOutput
  
  var didFinish: ((String?) -> Void)?
  var didUpdateIsContinueEnable: ((Bool) -> Void)?
  
  // MARK: - SendCommentModuleInput
  
  func finish() {
    didFinish?(sendCommentController.comment)
  }
  
  // MARK: - SendCommentViewModel
  
  var didUpdateComment: ((String) -> Void)?
  var didUpdatePlaceholder: ((String) -> Void)?
  var didUpdateDescription: ((NSAttributedString) -> Void)?
  var didUpdateDescriptionVisibility: ((Bool) -> Void)?
  
  func viewDidLoad() {
    sendCommentController.didUpdateIsCommentRequired = { [weak self] isRequired in
      if isRequired {
        self?.didUpdatePlaceholder?("Required comment")
        self?.didUpdateDescription?(
          "You must include the note from the exchange for transfer. Without it your funds will be lost.".withTextStyle(
            .body2,
            color: .Accent.orange,
            alignment: .left,
            lineBreakMode: .byWordWrapping
          )
        )
      } else {
        self?.didUpdatePlaceholder?("Comment")
        self?.didUpdateDescription?(
          "Will be visible to everyone.".withTextStyle(
            .body2,
            color: .Text.secondary,
            alignment: .left,
            lineBreakMode: .byWordWrapping
          )
        )
      }
    }
    
    sendCommentController.didUpdateDescriptionVisibility = { [weak self] isVisible in
      self?.didUpdateDescriptionVisibility?(isVisible)
    }
    
    sendCommentController.didUpdateIsContinueEnable = { [weak self] isEnable in
      self?.isContinueEnabled = isEnable
    }
    
    sendCommentController.didUpdateComment = { [weak self] comment in
      self?.didUpdateComment?(comment)
    }
    
    sendCommentController.start()
  }
  
  func viewDidAppear() {
    didUpdateIsContinueEnable?(isContinueEnabled)
  }
  
  func viewWillDisappear() {
    didUpdateIsContinueEnable?(isContinueEnabled)
  }
  
  func didEditComment(_ comment: String) {
    sendCommentController.setCommentInput(comment)
  }
  
  func didTapPasteButton() {
    guard let pasteboardString = UIPasteboard.general.string else { return }
    sendCommentController.setCommentInput(pasteboardString)
    didUpdateComment?(pasteboardString)
  }
  
  // MARK: - State
  
  private var isContinueEnabled: Bool = false {
    didSet {
      didUpdateIsContinueEnable?(isContinueEnabled)
    }
  }
  
  
  // MARK: - Dependencies
  
  private let sendCommentController: SendCommentController
  
  // MARK: - Init
  
  init(sendCommentController: SendCommentController) {
    self.sendCommentController = sendCommentController
  }
}

private extension SendCommentViewModelImplementation {}
