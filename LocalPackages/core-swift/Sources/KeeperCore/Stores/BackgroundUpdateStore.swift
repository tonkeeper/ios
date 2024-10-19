import Foundation

public final class BackgroundUpdateStore: StoreV3<BackgroundUpdateStore.Event, BackgroundUpdateStore.State> {
  public typealias State = [Wallet: ConnectionState]
  
  public enum ConnectionState: Equatable {
    case connecting
    case connected
    case disconnected
    case noConnection
  }
  
  public enum Event {
    case didUpdateConnectionState(ConnectionState, wallet: Wallet)
  }
  
  public init() {
    super.init(state: [:])
  }
  
  public override func createInitialState() -> State {
    [:]
  }
  
  public func setConnectionState(_ connectionState: ConnectionState, wallet: Wallet) async {
    await setState { state in
      var state = state
      state[wallet] = connectionState
      return StateUpdate(newState: state)
    } notify: { state in
      self.sendEvent(.didUpdateConnectionState(connectionState, wallet: wallet))
    }
  }
}
