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
  
  public override func createInitialState() -> State {
    [:]
  }
  
  public func getDecryptedComment(wallet: Wallet,
                                  payload: EncryptedCommentPayload,
                                  eventId: String) -> String? {
    let key = createKey(
      eventId: eventId,
      cipherText: payload.encryptedComment.cipherText,
      senderAddress: payload.senderAddress
    )
    guard let state = getState()[key] else {
      return nil
    }
    return state
  }
  
  public func setDecryptedComment(_ comment: String?,
                                  wallet: Wallet,
                                  payload: EncryptedCommentPayload,
                                  eventId: String) async {
    return await withCheckedContinuation { continuation in
      setDecryptedComment(
        comment,
        wallet: wallet,
        payload: payload,
        eventId: eventId) {
          continuation.resume()
        }
    }
  }
  
  public func setDecryptedComment(_ comment: String?,
                                  wallet: Wallet,
                                  payload: EncryptedCommentPayload,
                                  eventId: String,
                                  completion: (() -> Void)?) {
    let key = createKey(
      eventId: eventId,
      cipherText: payload.encryptedComment.cipherText,
      senderAddress: payload.senderAddress
    )
    updateState { state in
      var updatedState = state
      updatedState[key] = comment
      return StateUpdate(newState: updatedState)
    } completion: { [weak self] _ in
      self?.sendEvent(.didDecryptComment(eventId: eventId, wallet: wallet))
      completion?()
    }
  }
  
  private func createKey(eventId: String,
                         cipherText: String,
                         senderAddress: Address) -> Key {
    Key(
      eventId: eventId,
      cipherText: cipherText,
      senderAddress: senderAddress
    )
  }
}
