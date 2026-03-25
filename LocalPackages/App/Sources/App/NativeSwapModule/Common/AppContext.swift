import Foundation
import KeeperCore
import TKCore
import TonSwift

/// General application context that provides access to core dependencies
/// Can be reused across different features and modules
struct AppContext {
    let wallet: Wallet
    let configuration: Configuration
    let configurationAssembly: ConfigurationAssembly
    let appSettingsStore: AppSettingsStore
    let balanceStore: ConvertedBalanceStore
    let currencyStore: CurrencyStore
    let amountFormatter: AmountFormatter
    let analyticsProvider: AnalyticsProvider

    init(
        wallet: Wallet,
        keeperCoreAssembly: KeeperCore.MainAssembly,
        coreAssembly: TKCore.CoreAssembly
    ) {
        self.wallet = wallet
        self.configuration = keeperCoreAssembly.configurationAssembly.configuration
        self.configurationAssembly = keeperCoreAssembly.configurationAssembly
        self.appSettingsStore = keeperCoreAssembly.storesAssembly.appSettingsStore
        self.balanceStore = keeperCoreAssembly.storesAssembly.convertedBalanceStore
        self.currencyStore = keeperCoreAssembly.storesAssembly.currencyStore
        self.amountFormatter = keeperCoreAssembly.formattersAssembly.amountFormatter
        self.analyticsProvider = coreAssembly.analyticsProvider
    }
}

/// Extended context for swap-related features
struct SwapDependencies {
    let nativeSwapService: NativeSwapService
    let swapAssetsStore: SwapAssetsStore
    let ratesService: RatesService
    let sendController: SendV3Controller
    let resolveJettonInfo: (Address, Network) async throws -> JettonInfo

    init(
        wallet: Wallet,
        keeperCoreAssembly: KeeperCore.MainAssembly
    ) {
        self.nativeSwapService = keeperCoreAssembly.servicesAssembly.nativeSwapService()
        self.swapAssetsStore = keeperCoreAssembly.storesAssembly.swapAssetsStore
        self.ratesService = keeperCoreAssembly.servicesAssembly.ratesService()
        self.sendController = keeperCoreAssembly.sendV3Controller(wallet: wallet)
        self.resolveJettonInfo = { address, network in
            try await keeperCoreAssembly
                .servicesAssembly
                .jettonService()
                .jettonInfo(address: address, network: network)
        }
    }
}
