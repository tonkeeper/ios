import UIKit
import TKCore
import KeeperCore

struct ChartAssembly {
  private init() {}
  static func module(token: Token,
                     coreAssembly: TKCore.CoreAssembly,
                     keeperCoreMainAssembly: KeeperCore.MainAssembly) -> MVVMModule<ChartViewController, ChartModuleOutput, Void> {
    let viewModel = ChartViewModelImplementation(
      chartController: keeperCoreMainAssembly.chartV2Controller(token: token),
      currencyStore: keeperCoreMainAssembly.storesAssembly.currencyStore,
      chartFormatter: coreAssembly.formattersAssembly.chartFormatter(
        dateFormatter: keeperCoreMainAssembly.formattersAssembly.dateFormatter,
        decimalAmountFormatter: keeperCoreMainAssembly.formattersAssembly.decimalAmountFormatter
      )
    )
    
    let viewController = ChartViewController(viewModel: viewModel)
    return .init(view: viewController, output: viewModel, input: Void())
  }
  
  // вынести
  static func module(
    stakingPool: StakingPool,
    coreAssembly: TKCore.CoreAssembly,
    keeperCoreMainAssembly: KeeperCore.MainAssembly
  ) -> MVVMModule<ChartViewController, ChartModuleOutput, Void> {
    let viewModel = LPTokenChartViewModel(
      controller: keeperCoreMainAssembly.lpTokenChartController(stakingPool: stakingPool),
      amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter
    )

    let viewController = ChartViewController(viewModel: viewModel)
    return .init(view: viewController, output: viewModel, input: Void())
  }
}
