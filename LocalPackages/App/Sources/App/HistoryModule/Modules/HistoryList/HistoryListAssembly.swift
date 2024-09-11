import UIKit
import TKCore
import KeeperCore

struct HistoryListAssembly {
  private init() {}
  static func module(wallet: Wallet,
                     paginationLoader: HistoryPaginationLoader,
                     cacheProvider: HistoryListCacheProvider,
                     keeperCoreMainAssembly: KeeperCore.MainAssembly,
                     historyEventMapper: HistoryEventMapper) -> MVVMModule<HistoryListViewController, HistoryListModuleOutput, Void> {
    let viewModel = HistoryListViewModelImplementation(
      wallet: wallet,
      paginationLoader: paginationLoader,
      cacheProvider: cacheProvider,
      nftService: keeperCoreMainAssembly.servicesAssembly.nftService(),
      accountEventMapper: keeperCoreMainAssembly.mappersAssembly.historyAccountEventMapper,
      dateFormatter: keeperCoreMainAssembly.formattersAssembly.dateFormatter,
      historyEventMapper: historyEventMapper
    )
    let viewController = HistoryListViewController(viewModel: viewModel)
    return .init(view: viewController, output: viewModel, input: Void())
  }
}
