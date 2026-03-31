import Foundation
import TonSwift
import TONWalletKit

public protocol TONWalletKitEventsObserver: AnyObject {
    func didReceiveConnectRequest(_ request: TONWalletConnectionRequest)
    func didReceiveTransactionRequest(_ request: TONWalletSendTransactionRequest, wallet: Wallet, app: TonConnectApp)
    func didReceiveSignDataRequest(_ request: TONWalletSignDataRequest, wallet: Wallet, app: TonConnectApp)
}

public final class TONConnectEventsHandler: TONBridgeEventsHandler {
    private var walletKitObservers = [TONWalletKitEventsObserverWrapper]()
    private let walletsStore: WalletsStore
    private let tonConnectAppsStore: TonConnectAppsStore

    public init(
        walletsStore: WalletsStore,
        tonConnectAppsStore: TonConnectAppsStore
    ) {
        self.walletsStore = walletsStore
        self.tonConnectAppsStore = tonConnectAppsStore
    }

    // MARK: - TONWalletKit Events Observer

    public func addWalletKitObserver(_ observer: TONWalletKitEventsObserver) {
        removeNilWalletKitObservers()
        walletKitObservers.append(TONWalletKitEventsObserverWrapper(observer: observer))
    }

    private func removeNilWalletKitObservers() {
        walletKitObservers.removeAll { $0.observer == nil }
    }

    // MARK: - Event Handling

    public func handle(event: TONWalletKitEvent) throws {
        // Because, in navigation system, events received from web view are handled separated from remote events
        // We need to ignore events from JS. Otherwise there might be potential issue with navigation
        if event.isJsBridge { return }

        DispatchQueue.main.async { [weak self] in
            switch event {
            case let .connectRequest(request):
                self?.notifyWalletKitObservers { $0.didReceiveConnectRequest(request) }
            case let .transactionRequest(request):
                self?.handleTransactionRequest(request)
            case let .signDataRequest(request):
                self?.handleSignDataRequest(request)
            case .disconnect: ()
            }
        }
    }

    private func handleTransactionRequest(_ request: TONWalletSendTransactionRequest) {
        let event = request.event

        guard let walletId = event.walletId,
              let wallet = findWallet(byId: walletId),
              let app = findApp(forWallet: wallet, clientId: event.from)
        else {
            return
        }

        notifyWalletKitObservers { $0.didReceiveTransactionRequest(request, wallet: wallet, app: app) }
    }

    private func handleSignDataRequest(_ request: TONWalletSignDataRequest) {
        let event = request.event

        guard let walletId = event.walletId,
              let wallet = findWallet(byId: walletId),
              let app = findApp(forWallet: wallet, clientId: event.from)
        else {
            return
        }

        notifyWalletKitObservers { $0.didReceiveSignDataRequest(request, wallet: wallet, app: app) }
    }

    private func notifyWalletKitObservers(_ action: (TONWalletKitEventsObserver) -> Void) {
        for wrapper in walletKitObservers {
            if let observer = wrapper.observer {
                action(observer)
            }
        }
    }

    // MARK: - Wallet & App Lookup

    private func findWallet(byId walletId: String) -> Wallet? {
        walletsStore.wallets.first { (try? $0.walletKitIdentifier) == walletId }
    }

    private func findApp(forWallet wallet: Wallet, clientId: String?) -> TonConnectApp? {
        guard let clientId = clientId,
              let apps = try? tonConnectAppsStore.connectedApps(forWallet: wallet)
        else {
            return nil
        }
        return apps.apps.first { $0.clientId == clientId }
    }
}

private struct TONWalletKitEventsObserverWrapper {
    weak var observer: TONWalletKitEventsObserver?
}
