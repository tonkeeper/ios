import Foundation

public enum BackgroundUpdateConnectionState: Equatable, Sendable {
    case connecting
    case connected
    case disconnected
    case noConnection
}

public struct BackgroundUpdateStateUpdate: Sendable, Equatable {
    public let walletID: String
    public let walletSelectionID: UUID
    public let state: BackgroundUpdateConnectionState

    public init(
        walletID: String,
        walletSelectionID: UUID,
        state: BackgroundUpdateConnectionState
    ) {
        self.walletID = walletID
        self.walletSelectionID = walletSelectionID
        self.state = state
    }
}
