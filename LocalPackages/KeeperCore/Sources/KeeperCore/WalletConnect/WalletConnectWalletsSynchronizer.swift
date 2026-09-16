import Foundation
import TKLogging

@WalletConnectActor
public final class WalletConnectWalletsSynchronizer: Sendable {
    private let walletConnectService: any WalletConnectService
    private let walletsStore: WalletsStore

    private var didStart = false

    init(
        walletConnectService: any WalletConnectService,
        walletsStore: WalletsStore
    ) {
        self.walletConnectService = walletConnectService
        self.walletsStore = walletsStore
    }

    public func startAutoDisconnect() {
        guard !didStart else { return }
        didStart = true

        walletsStore.addObserver(self) { [weak self] _, event in
            switch event {
            case let .didDeleteWallet(wallet):
                Task {
                    await self?.disconnectSessions(walletId: wallet.id)
                }
            case .didDeleteAll:
                Task {
                    await self?.disconnectAllSessions()
                }
            default:
                break
            }
        }
    }
}

private extension WalletConnectWalletsSynchronizer {
    func disconnectSessions(walletId: String) async {
        let sessions = await walletConnectService.activeSessions()
            .filter { $0.walletId == walletId }

        for session in sessions {
            await disconnect(session, context: "deleted wallet")
        }
    }

    func disconnectAllSessions() async {
        let sessions = await walletConnectService.activeSessions()
        for session in sessions {
            await disconnect(session, context: "all wallets deleted")
        }
    }

    func disconnect(
        _ session: WalletConnectSession,
        context: String
    ) async {
        do {
            try await walletConnectService.disconnect(topic: session.topic)
        } catch {
            Log.walletConnect.w(
                "failed to disconnect session after \(context)",
                error: error
            )
            await removeLocalSession(session, context: context)
        }
    }

    func removeLocalSession(
        _ session: WalletConnectSession,
        context: String
    ) async {
        do {
            try await walletConnectService.removeLocalSession(topic: session.topic)
        } catch {
            Log.walletConnect.w(
                "failed to remove local session after \(context)",
                error: error
            )
        }
    }
}
