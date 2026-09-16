import KeeperCore
import TKCore
import UIKit

struct ChartAssembly {
    private init() {}
    static func module(
        token: Token,
        wallet: Wallet,
        coreAssembly: TKCore.CoreAssembly,
        keeperCoreMainAssembly: KeeperCore.MainAssembly
    ) -> MVVMModule<ChartViewController, ChartModuleOutput, Void> {
        module(
            chartController: keeperCoreMainAssembly.chartV2Controller(token: token, wallet: wallet),
            coreAssembly: coreAssembly,
            keeperCoreMainAssembly: keeperCoreMainAssembly
        )
    }

    static func module(
        chartController: ChartV2Controller,
        coreAssembly: TKCore.CoreAssembly,
        keeperCoreMainAssembly: KeeperCore.MainAssembly
    ) -> MVVMModule<ChartViewController, ChartModuleOutput, Void> {
        let viewModel = makeViewModel(
            chartController: chartController,
            coreAssembly: coreAssembly,
            keeperCoreMainAssembly: keeperCoreMainAssembly
        )
        let viewController = ChartViewController(viewModel: viewModel)
        return .init(view: viewController, output: viewModel, input: ())
    }

    static func viewState(
        chartController: ChartV2Controller,
        coreAssembly: TKCore.CoreAssembly,
        keeperCoreMainAssembly: KeeperCore.MainAssembly
    ) -> TokenChartViewState {
        TokenChartViewState(
            viewModel: makeViewModel(
                chartController: chartController,
                coreAssembly: coreAssembly,
                keeperCoreMainAssembly: keeperCoreMainAssembly
            )
        )
    }

    private static func makeViewModel(
        chartController: ChartV2Controller,
        coreAssembly: TKCore.CoreAssembly,
        keeperCoreMainAssembly: KeeperCore.MainAssembly
    ) -> ChartViewModelImplementation {
        ChartViewModelImplementation(
            chartController: chartController,
            currencyStore: keeperCoreMainAssembly.storesAssembly.currencyStore,
            chartFormatter: coreAssembly.formattersAssembly.chartFormatter(
                dateFormatter: keeperCoreMainAssembly.formattersAssembly.dateFormatter,
                amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter,
                signedAmountFormatter: keeperCoreMainAssembly.formattersAssembly.signedAmountFormatter
            )
        )
    }
}
