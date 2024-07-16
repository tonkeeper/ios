import Foundation
import TonSwift

public final class BackgroundUpdateStoreV2: Store<BackgroundUpdateStoreV2.State> {
  public enum State: Equatable {
    case connecting(addresses: [Address])
    case connected(addresses: [Address])
    case disconnected
    case noConnection
  }
  
  public init() {
    super.init(state: .disconnected)
  }
}
