import Foundation
import TKLogging

public final class WidgetAssembly {
    private let repositoriesAssembly: RepositoriesAssembly
    private let servicesAssembly: ServicesAssembly
    private let storesAssembly: StoresAssembly
    private let coreAssembly: CoreAssembly
    private let formattersAssembly: FormattersAssembly
    private let walletsUpdateAssembly: WalletsUpdateAssembly
    private let apiAssembly: APIAssembly
    private let loadersAssembly: LoadersAssembly
    private let tradingAssembly: TradingAssembly

    init(
        repositoriesAssembly: RepositoriesAssembly,
        coreAssembly: CoreAssembly,
        servicesAssembly: ServicesAssembly,
        storesAssembly: StoresAssembly,
        formattersAssembly: FormattersAssembly,
        walletsUpdateAssembly: WalletsUpdateAssembly,
        apiAssembly: APIAssembly,
        loadersAssembly: LoadersAssembly,
        tradingAssembly: TradingAssembly
    ) {
        self.repositoriesAssembly = repositoriesAssembly
        self.coreAssembly = coreAssembly
        self.servicesAssembly = servicesAssembly
        self.storesAssembly = storesAssembly
        self.formattersAssembly = formattersAssembly
        self.walletsUpdateAssembly = walletsUpdateAssembly
        self.apiAssembly = apiAssembly
        self.loadersAssembly = loadersAssembly
        self.tradingAssembly = tradingAssembly
    }

    public var walletsService: WalletsService {
        servicesAssembly.walletsService()
    }

    public func currenciesService() -> CurrenciesService {
        servicesAssembly.currenciesService()
    }

    public func chartV2Controller(token: Token) -> ChartV2Controller {
        guard let wallet = activeWallet() else {
            return chartV2Controller(
                asset: .legacy(token: token.chartIdentifier),
                network: .mainnet
            )
        }
        return chartV2Controller(
            asset: ChartAsset(token: token, wallet: wallet),
            network: wallet.network
        )
    }

    /// A trading catalog asset's chart, which needs no wallet.
    public func chartV2Controller(assetId: String) -> ChartV2Controller {
        chartV2Controller(asset: .multichain(assetId: assetId), network: .mainnet)
    }

    /// The app's currency, from the keeper info the app shares with its extensions.
    public var currency: Currency {
        (try? repositoriesAssembly.keeperInfoRepository().getKeeperInfo().currency) ?? .defaultCurrency
    }

    /// Prices and 24-hour changes from the trading catalog, in the app's currency, for up to 10 assets: the
    /// backend rejects more in one request. Assets the catalog does not know are left out.
    public func marketItems(assetIDs: [String]) async throws -> [TradingMarketItem] {
        let requestContext = await tradingAssembly.requestContextProvider.makeRequestContext()
        return try await tradingAssembly.api.getAssets(requestContext: requestContext, ids: assetIDs).items
            .map(TradingMarketItem.init(item:))
    }

    private func chartV2Controller(
        asset: ChartAsset,
        network: Network
    ) -> ChartV2Controller {
        ChartV2Controller(
            asset: asset,
            network: network,
            chartService: widgetChartService(),
            currencyStore: storesAssembly.currencyStore
        )
    }

    private func activeWallet() -> Wallet? {
        do {
            return try servicesAssembly.walletsService().getActiveWallet()
        } catch {
            Log.w("failed to resolve active wallet for widget chart", error: error)
            return nil
        }
    }
}

private extension WidgetAssembly {
    func widgetChartService() -> ChartService {
        servicesAssembly.chartService(
            repository: repositoriesAssembly.persistentChartDataRepository()
        )
    }
}
