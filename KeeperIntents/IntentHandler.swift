import Intents
import KeeperCore
import TKCore
import UIKit
import WalletExtensions

class IntentHandler: INExtension, RateWidgetIntentHandling, BalanceWidgetIntentHandling {
    func provideWalletOptionsCollection(for intent: BalanceWidgetIntent) async throws -> INObjectCollection<WidgetWallet> {
        let keeperCoreAssembly = makeKeeperCoreAssembly()

        let widgetAssembly = keeperCoreAssembly.widgetAssembly()
        let walletsService = widgetAssembly.walletsService
        let wallets = try walletsService.getWallets()
        let widgetWallets = wallets.compactMap { wallet in
            let display: String
            var image: INImage?
            switch wallet.icon {
            case let .emoji(emoji):
                display = "\(emoji)    \(wallet.label)"
                image = nil
            case let .icon(icon):
                if let data = icon.image?.pngData() {
                    image = INImage(imageData: data)
                }
                display = wallet.label
            }
            let item = try? WidgetWallet(identifier: wallet.identity.identifier().string, display: display)
            item?.displayImage = image
            return item
        }
        return INObjectCollection(items: widgetWallets)
    }

    func provideCurrencyOptionsCollection(
        for intent: BalanceWidgetIntent,
        with completion: @escaping (INObjectCollection<WidgetCurrency>?, Error?) -> Void
    ) {
        provideCurrencyOptionsCollection(completion: completion)
    }

    func provideCurrencyOptionsCollection(
        for intent: RateWidgetIntent,
        with completion: @escaping (INObjectCollection<WidgetCurrency>?, Error?) -> Void
    ) {
        provideCurrencyOptionsCollection(completion: completion)
    }

    private func provideCurrencyOptionsCollection(
        completion: @escaping (INObjectCollection<WidgetCurrency>?, Error?) -> Void
    ) {
        let keeperCoreAssembly = makeKeeperCoreAssembly()
        let selectedCurrency = keeperCoreAssembly.rootAssembly().storesAssembly.currencyStore.state
        let currenciesService = keeperCoreAssembly.widgetAssembly().currenciesService()

        Task {
            defer { withExtendedLifetime(keeperCoreAssembly) {} }
            let remoteCurrencies = (try? await currenciesService.loadCurrencies()) ?? []
            var seen = Set<Currency>()
            var items = remoteCurrencies.compactMap { remote -> WidgetCurrency? in
                guard let currency = Currency(code: remote.code), seen.insert(currency).inserted else {
                    return nil
                }
                return WidgetCurrency(identifier: currency.code, display: remote.code)
            }
            if seen.insert(selectedCurrency).inserted {
                items.insert(
                    WidgetCurrency(identifier: selectedCurrency.code, display: selectedCurrency.code),
                    at: 0
                )
            }
            completion(INObjectCollection(items: items), nil)
        }
    }

    private func makeKeeperCoreAssembly() -> KeeperCore.Assembly {
        let coreAssembly = TKCore.CoreAssembly()
        return KeeperCore.Assembly(
            dependencies: Assembly.Dependencies(
                cacheURL: coreAssembly.cacheURL,
                sharedCacheURL: coreAssembly.sharedCacheURL,
                appInfoProvider: coreAssembly.appInfoProvider,
                featureFlags: coreAssembly.featureFlags,
                seedProvider: { "" }
            )
        )
    }
}
