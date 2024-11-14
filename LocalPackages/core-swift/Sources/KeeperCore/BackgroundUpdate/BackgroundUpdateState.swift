import Foundation

public enum BackgroundUpdateConnectionState: Equatable {
  case connecting
  case connected
  case disconnected
  case noConnection
}
