import UIKit
import TKCore
import KeeperCore

struct TonConnectConfirmationAssembly {
  private init() {}
  static func module(model: TonConnectConfirmationController.Model, historyEventMapper: HistoryEventMapper) -> MVVMModule<TonConnectConfirmationViewController, TonConnectConfirmationModuleOutput, Void> {
    let viewModel = TonConnectConfirmationViewModelImplementation(
      model: model,
      historyEventMapper: historyEventMapper
    )
    let viewController = TonConnectConfirmationViewController(viewModel: viewModel)
    return .init(view: viewController, output: viewModel, input: Void())
  }
}
