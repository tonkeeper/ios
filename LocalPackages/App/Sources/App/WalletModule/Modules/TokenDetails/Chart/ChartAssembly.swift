import UIKit
import TKCore
import KeeperCore

struct ChartAssembly {
  private init() {}
  static func module(chartController: ChartV2Controller) -> MVVMModule<ChartViewController, ChartModuleOutput, Void> {
    let viewModel = ChartViewModelImplementation(chartController: chartController)
    let viewController = ChartViewController(viewModel: viewModel)
    return .init(view: viewController, output: viewModel, input: Void())
  }
}
