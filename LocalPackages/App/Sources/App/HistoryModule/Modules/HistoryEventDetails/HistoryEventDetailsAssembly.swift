import Foundation
import TKCore
import KeeperCore

struct HistoryEventDetailsAssembly {
  private init() {}
  static func module(
    historyEventDetailsController: HistoryEventDetailsController,
    urlOpener: URLOpener
  ) -> MVVMModule<HistoryEventDetailsViewController, HistoryEventDetailsModuleOutput, Void> {
    let viewModel = HistoryEventDetailsViewModelImplementation(
      historyEventDetailsController: historyEventDetailsController,
      urlOpener: urlOpener
    )
    let viewController = HistoryEventDetailsViewController(viewModel: viewModel)
    return .init(view: viewController, output: viewModel, input: Void())
  }
}
