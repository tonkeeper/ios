import Combine
@testable import KeeperCore
import ReownWalletKit
import XCTest

final class WalletConnectNetworkConnectionStatusProviderTests: XCTestCase {
    func testProviderReadsCurrentNetworkMonitorStatus() async {
        let networkMonitor = WalletConnectNetworkMonitorMock(isConnected: true)
        let provider = await WalletConnectNetworkConnectionStatusProvider(networkMonitor: networkMonitor)

        let isConnected = await provider.isConnected

        XCTAssertTrue(isConnected)
    }

    func testProviderReadsUpdatedNetworkMonitorStatus() async {
        let networkMonitor = WalletConnectNetworkMonitorMock(isConnected: true)
        let provider = await WalletConnectNetworkConnectionStatusProvider(networkMonitor: networkMonitor)

        networkMonitor.setConnected(false)

        let isConnected = await provider.isConnected

        XCTAssertFalse(isConnected)
    }

    @WalletConnectActor
    func testProviderExposesNetworkConnectionStatus() {
        let networkMonitor = WalletConnectNetworkMonitorMock(isConnected: false)
        let provider = WalletConnectNetworkConnectionStatusProvider(networkMonitor: networkMonitor)

        switch provider.status {
        case .notConnected:
            break
        case .connected:
            XCTFail("Expected provider to expose notConnected status")
        }
    }
}

private final class WalletConnectNetworkMonitorMock: NetworkMonitoring, @unchecked Sendable {
    private let lock = NSLock()
    private var connected: Bool

    init(isConnected: Bool) {
        self.connected = isConnected
    }

    var isConnected: Bool {
        lock.lock()
        defer { lock.unlock() }
        return connected
    }

    var networkConnectionStatusPublisher: AnyPublisher<NetworkConnectionStatus, Never> {
        Empty().eraseToAnyPublisher()
    }

    func setConnected(_ isConnected: Bool) {
        lock.lock()
        defer { lock.unlock() }
        connected = isConnected
    }
}
