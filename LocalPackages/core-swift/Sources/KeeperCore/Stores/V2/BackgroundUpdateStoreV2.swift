import Foundation
import TonSwift

public final class BackgroundUpdateStoreV2: Store<BackgroundUpdateStoreV2.State> {
  public enum State: Equatable {
    case connecting
    case connected
    case disconnected
    case noConnection
  }
  
  public init() {
    super.init(state: .disconnected)
  }
}
