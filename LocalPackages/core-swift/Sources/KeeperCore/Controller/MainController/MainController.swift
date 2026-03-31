import Foundation
import TKFeatureFlags
import TonSwift

public final class MainController {
    public var didReceiveTonConnectRequest: ((TonConnect.AppRequest, Wallet, TonConnectApp) -> Void)?

    private var updatesStarted = false

    private let backgroundUpdate: BackgroundUpdate
    private let tonConnectEventsStore: TonConnectEventsStore
    private let tonConnectService: TonConnectService
    private let configurationAssembly: ConfigurationAssembly
    private let deeplinkParser: DeeplinkParser

    private let balanceLoader: BalanceLoader
    private let walletInfoLoader: WalletInfoLoader

    private let internalNotificationsLoader: InternalNotificationsLoader
    private let storiesLoader: StoriesLoader
    private let tronUSDTFeesService: TronUsdtFeesService

    init(
        backgroundUpdate: BackgroundUpdate,
        tonConnectEventsStore: TonConnectEventsStore,
        tonConnectService: TonConnectService,
        deeplinkParser: DeeplinkParser,
        balanceLoader: BalanceLoader,
        internalNotificationsLoader: InternalNotificationsLoader,
        walletInfoLoader: WalletInfoLoader,
        storiesLoader: StoriesLoader,
        tronUSDTFeesService: TronUsdtFeesService,
        configurationAssembly: ConfigurationAssembly
    ) {
        self.backgroundUpdate = backgroundUpdate
        self.tonConnectEventsStore = tonConnectEventsStore
        self.tonConnectService = tonConnectService
        self.deeplinkParser = deeplinkParser
        self.balanceLoader = balanceLoader
        self.internalNotificationsLoader = internalNotificationsLoader
        self.walletInfoLoader = walletInfoLoader
        self.storiesLoader = storiesLoader
        self.tronUSDTFeesService = tronUSDTFeesService
        self.configurationAssembly = configurationAssembly

        backgroundUpdate.addEventObserver(self) { [weak self] _, wallet, _ in
            DispatchQueue.main.async {
                self?.balanceLoader.loadWalletBalance(wallet: wallet)
            }
        }
    }

    public func start() {
        startUpdates()
        internalNotificationsLoader.loadNotifications()
        storiesLoader.loadStories()
    }

    public func startUpdates() {
        guard !updatesStarted else { return }
        balanceLoader.loadActiveWalletBalance()
        walletInfoLoader.loadActiveWalletInfoNotifications()
        balanceLoader.startActiveWalletBalanceReload()
        backgroundUpdate.start()
        tronUSDTFeesService.start()

        if !configurationAssembly.configuration.featureEnabled(.walletKitEnabled) {
            Task {
                await tonConnectEventsStore.addObserver(self)
                await tonConnectEventsStore.start()
                await MainActor.run {
                    updatesStarted = true
                }
            }
        }
    }

    public func stopUpdates() {
        balanceLoader.stopActiveWalletBalanceReload()
        backgroundUpdate.stop()
        tronUSDTFeesService.stop()

        if !configurationAssembly.configuration.featureEnabled(.walletKitEnabled) {
            Task {
                await tonConnectEventsStore.stop()
                await tonConnectEventsStore.removeObserver(self)
                await MainActor.run {
                    updatesStarted = false
                }
            }
        }
    }

    public func parseDeeplink(deeplink: String?) throws -> Deeplink {
        try deeplinkParser.parse(string: deeplink)
    }
}

extension MainController: TonConnectEventsStoreObserver {
    public func didGetTonConnectEventsStoreEvent(_ event: TonConnectEventsStore.Event) {
        switch event {
        case let .request(request, wallet, app):
            Task { @MainActor in
                didReceiveTonConnectRequest?(request, wallet, app)
            }
        }
    }
}
