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

    init(
        repositoriesAssembly: RepositoriesAssembly,
        coreAssembly: CoreAssembly,
        servicesAssembly: ServicesAssembly,
        storesAssembly: StoresAssembly,
        formattersAssembly: FormattersAssembly,
        walletsUpdateAssembly: WalletsUpdateAssembly,
        apiAssembly: APIAssembly,
        loadersAssembly: LoadersAssembly
    ) {
        self.repositoriesAssembly = repositoriesAssembly
        self.coreAssembly = coreAssembly
        self.servicesAssembly = servicesAssembly
        self.storesAssembly = storesAssembly
        self.formattersAssembly = formattersAssembly
        self.walletsUpdateAssembly = walletsUpdateAssembly
        self.apiAssembly = apiAssembly
        self.loadersAssembly = loadersAssembly
    }

    public var walletsService: WalletsService {
        servicesAssembly.walletsService()
    }

    public func balanceWidgetController() -> BalanceWidgetController {
        BalanceWidgetController(
            walletService: servicesAssembly.walletsService(),
            balanceService: servicesAssembly.balanceService(),
            ratesService: servicesAssembly.ratesService(),
            amountFormatter: formattersAssembly.amountFormatter
        )
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
