@preconcurrency import ReownWalletKit

@WalletConnectActor
final class WalletConnectNetworkConnectionStatusProvider: Sendable {
    private let networkMonitor: any NetworkMonitoring

    init(networkMonitor: any NetworkMonitoring = NetworkMonitor()) {
        self.networkMonitor = networkMonitor
    }

    var status: NetworkConnectionStatus {
        networkMonitor.isConnected ? .connected : .notConnected
    }

    var isConnected: Bool {
        networkMonitor.isConnected
    }
}
