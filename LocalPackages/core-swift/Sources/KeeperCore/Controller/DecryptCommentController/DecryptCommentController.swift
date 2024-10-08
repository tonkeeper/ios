import Foundation

public final class DecryptCommentController {
  private let encryptedCommentService: EncryptedCommentService
  private let decryptedCommentStore: DecryptedCommentStore
  
  init(encryptedCommentService: EncryptedCommentService, 
       decryptedCommentStore: DecryptedCommentStore) {
    self.encryptedCommentService = encryptedCommentService
    self.decryptedCommentStore = decryptedCommentStore
  }
  
  public func decryptComment(_ payload: EncryptedCommentPayload, 
                             wallet: Wallet,
                             eventId: String,
                             passcode: String) async throws {
    let decryptedComment = try await encryptedCommentService.decryptComment(
      payload: payload,
      wallet: wallet,
      passcode: passcode
    )
    
    await decryptedCommentStore.setDecryptedComment(
      decryptedComment,
      wallet: wallet,
      payload: payload,
      eventId: eventId
    )
  }
}
