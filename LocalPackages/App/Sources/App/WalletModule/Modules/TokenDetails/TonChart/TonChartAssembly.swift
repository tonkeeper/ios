import UIKit
import TKCore
import KeeperCore

struct TonChartAssembly {
  static func module(chartController: ChartController) -> MVVMModule<TonChartViewController, Void, TonChartModuleInput> {
    let presenter = TonChartPresenter(chartController: chartController)
    
    let viewController = TonChartViewController(presenter: presenter)
    presenter.viewInput = viewController
    
    return MVVMModule(view: viewController, output: Void(), input: presenter)
  }
}
