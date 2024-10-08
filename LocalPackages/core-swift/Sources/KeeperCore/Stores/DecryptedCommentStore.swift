import Foundation
import TonSwift

public final class DecryptedCommentStore: StoreV3<DecryptedCommentStore.Event, DecryptedCommentStore.State> {
  public typealias State = [Key: String?]
  
  public struct Key: Hashable {
    let eventId: String
    let cipherText: String
    let senderAddress: Address
  }
  
  public enum Event {
    case didDecryptComment(eventId: String, wallet: Wallet)
  }
  
  init() {
    super.init(state: [:])
  }
  
  public override var initialState: State {
    [:]
  }
  
  public func setDecryptedComment(_ comment: String?, 
                                  wallet: Wallet,
                                  payload: EncryptedCommentPayload,
                                  eventId: String) async {
    let key = Key(
      eventId: eventId,
      cipherText: payload.encryptedComment.cipherText,
      senderAddress: payload.senderAddress
    )
    await setState { state in
      var updatedState = state
      updatedState[key] = comment
      return StateUpdate(newState: updatedState)
    } notify: { _ in
      self.sendEvent(.didDecryptComment(eventId: eventId, wallet: wallet))
    }
  }
  
  public func getDecryptedComment(wallet: Wallet,
                                  payload: EncryptedCommentPayload,
                                  eventId: String) -> String? {
    let key = Key(
      eventId: eventId,
      cipherText: payload.encryptedComment.cipherText,
      senderAddress: payload.senderAddress
    )
    guard let state = getState()[key] else {
      return nil
    }
    return state
  }
}
