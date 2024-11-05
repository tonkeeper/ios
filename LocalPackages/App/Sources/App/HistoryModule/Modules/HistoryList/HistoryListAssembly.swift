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
      appSettingsStore: keeperCoreMainAssembly.storesAssembly.appSettingsStore,
      backgroundUpdate: keeperCoreMainAssembly.backgroundUpdateAssembly.backgroundUpdate,
      decryptedCommentStore: keeperCoreMainAssembly.storesAssembly.decryptedCommentStore,
      nftService: keeperCoreMainAssembly.servicesAssembly.nftService(),
      cacheProvider: cacheProvider,
      dateFormatter: keeperCoreMainAssembly.formattersAssembly.dateFormatter,
      accountEventMapper: keeperCoreMainAssembly.mappersAssembly.historyAccountEventMapper,
      historyEventMapper: historyEventMapper
    )
    let viewController = HistoryListViewController(viewModel: viewModel)
    return .init(view: viewController, output: viewModel, input: Void())
  }
}
