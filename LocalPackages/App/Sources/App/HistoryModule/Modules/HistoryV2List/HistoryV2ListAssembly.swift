import UIKit
import TKCore
import KeeperCore

struct HistoryV2ListAssembly {
  private init() {}
  static func module(wallet: Wallet,
                     paginationLoader: HistoryPaginationLoader,
                     keeperCoreMainAssembly: KeeperCore.MainAssembly,
                     historyEventMapper: HistoryEventMapper) -> MVVMModule<HistoryV2ListViewController, HistoryV2ListModuleOutput, HistoryV2ListModuleInput> {
    let viewModel = HistoryV2ListViewModelImplementation(
      wallet: wallet,
      paginationLoader: paginationLoader,
      nftService: keeperCoreMainAssembly.servicesAssembly.nftService(),
      accountEventMapper: keeperCoreMainAssembly.mappersAssembly.historyAccountEventMapper,
      dateFormatter: keeperCoreMainAssembly.formattersAssembly.dateFormatter,
      historyEventMapper: historyEventMapper
    )
    let viewController = HistoryV2ListViewController(viewModel: viewModel)
    return .init(view: viewController, output: viewModel, input: viewModel)
  }
}
