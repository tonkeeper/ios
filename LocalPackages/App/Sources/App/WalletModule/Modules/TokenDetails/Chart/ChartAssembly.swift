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
      currencyStore: keeperCoreMainAssembly.storesAssembly.currencyStoreV2,
      chartFormatter: coreAssembly.formattersAssembly.chartFormatter(
        dateFormatter: keeperCoreMainAssembly.formattersAssembly.dateFormatter,
        decimalAmountFormatter: keeperCoreMainAssembly.formattersAssembly.decimalAmountFormatter
      )
    )
    let viewController = ChartViewController(viewModel: viewModel)
    return .init(view: viewController, output: viewModel, input: Void())
  }
}
