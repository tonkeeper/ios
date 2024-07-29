import Foundation
import TonSwift

public final class BackgroundUpdateStore: Store<BackgroundUpdateStore.State> {
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
