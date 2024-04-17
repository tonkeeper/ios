import Foundation
import TKCore
import KeeperCore

struct BuyListPopUpAssembly {
  private init() {}
  static func module(
    buySellItemModel: BuySellItemModel,
    appSettings: AppSettings,
//    historyEventDetailsController: HistoryEventDetailsController,
    urlOpener: URLOpener
  ) -> MVVMModule<BuyListPopUpViewController, BuyListPopUpModuleOutput, Void> {
    let viewModel = BuyListPopUpViewModelImplementation(
      buySellItemModel: buySellItemModel,
      appSettings: appSettings,
      urlOpener: urlOpener
    )
    let viewController = BuyListPopUpViewController(viewModel: viewModel)
    return .init(view: viewController, output: viewModel, input: Void())
  }
}
