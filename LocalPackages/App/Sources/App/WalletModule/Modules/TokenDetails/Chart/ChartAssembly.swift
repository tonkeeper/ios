import KeeperCore
import TKCore
import UIKit

struct ChartAssembly {
    private init() {}
    static func module(
        token: Token,
        coreAssembly: TKCore.CoreAssembly,
        keeperCoreMainAssembly: KeeperCore.MainAssembly
    ) -> MVVMModule<ChartViewController, ChartModuleOutput, Void> {
        let viewModel = ChartViewModelImplementation(
            chartController: keeperCoreMainAssembly.chartV2Controller(token: token),
            currencyStore: keeperCoreMainAssembly.storesAssembly.currencyStore,
            chartFormatter: coreAssembly.formattersAssembly.chartFormatter(
                dateFormatter: keeperCoreMainAssembly.formattersAssembly.dateFormatter,
                amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter
            )
        )
        let viewController = ChartViewController(viewModel: viewModel)
        return .init(view: viewController, output: viewModel, input: ())
    }
}
