import Foundation
import TonSwift

public final class SendCommentController {
  
  public var didUpdateComment: ((String) -> Void)?
  public var didUpdateIsCommentRequired: ((Bool) -> Void)?
  public var didUpdateDescriptionVisibility: ((Bool) -> Void)?
  public var didUpdateIsContinueEnable: ((Bool) -> Void)?
  
  public private(set) var comment = ""
  private var isCommentRequired = false
  
  init(isCommentRequired: Bool, comment: String?) {
    self.isCommentRequired = isCommentRequired
    self.comment = comment ?? ""
  }
  
  public func start() {
    didUpdateComment?(comment)
    updateCommentRequired()
    updateDescriptionVisibility()
    updateIsContinueEnable()
  }
  
  public func setCommentInput(_ comment: String) {
    self.comment = comment
    updateDescriptionVisibility()
    updateIsContinueEnable()
  }
}

private extension SendCommentController {
  func updateCommentRequired() {
    didUpdateIsCommentRequired?(isCommentRequired)
  }
  
  func updateDescriptionVisibility() {
    if isCommentRequired {
      didUpdateDescriptionVisibility?(true)
    } else {
      guard !isCommentRequired else {
        didUpdateDescriptionVisibility?(true)
        return
      }
      let isVisible = comment.isEmpty
      didUpdateDescriptionVisibility?(isVisible)
    }
  }
  
  func updateIsContinueEnable() {
    let isEnable = !isCommentRequired || !comment.isEmpty
    didUpdateIsContinueEnable?(isEnable)
  }
}
