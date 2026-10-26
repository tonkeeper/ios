import KeeperCore
import TKCore

@MainActor
final class EarnDappSession {
    private let analytics: EarnDappAnalytics
    private let openSession: DappOpenAnalyticsSession
    private var isClosed = false

    init(analyticsProvider: AnalyticsProvider, openSession: DappOpenAnalyticsSession, dappUrl: String?) {
        self.analytics = EarnDappAnalytics(
            analyticsProvider: analyticsProvider,
            from: openSession.context.from,
            utm: openSession.context.utm,
            dappUrl: dappUrl
        )
        self.openSession = openSession
    }

    func logSigning(_ event: EarnSigningEvent) {
        analytics.logSigning(event)
    }

    func logTransactionSent(wallet: Wallet, chain: WalletConnectChain, transaction: WalletConnectEVMTransaction) {
        analytics.logTransactionSent(wallet: wallet, chain: chain, transaction: transaction)
    }

    func trackPageEvent(name: String, params: [String: Any]) {
        analytics.logPageEvent(name: name, params: params)
    }

    func close(via exitMethod: EarnExitMethod) {
        guard !isClosed else { return }
        isClosed = true
        analytics.logClose(exitMethod: exitMethod, durationMs: openSession.millisecondsSinceClick())
    }
}
