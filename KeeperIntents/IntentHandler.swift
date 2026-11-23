import Intents
import KeeperCore
import TKAppInfo
import TKFeatureFlags

class IntentHandler: INExtension, RateWidgetIntentHandling {
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
        KeeperCore.Assembly(
            dependencies: Assembly.Dependencies(
                cacheURL: AppDirectories.documents,
                sharedCacheURL: AppDirectories.sharedCache,
                appInfoProvider: DeviceAppInfoProvider(
                    userDefaults: .standard,
                    storefrontCountryCodeCache: StorefrontCountryCodeCache()
                ),
                featureFlags: DummyFeatureFlags(),
                seedProvider: { "" }
            )
        )
    }
}
