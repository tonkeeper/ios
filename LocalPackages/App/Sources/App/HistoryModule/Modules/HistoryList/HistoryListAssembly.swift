import KeeperCore
import TKCore
import UIKit

struct HistoryListAssembly {
    private init() {}
    static func module(
        wallet: Wallet,
        paginationLoader: HistoryPaginationLoader,
        cacheProvider: HistoryListCacheProvider,
        keeperCoreMainAssembly: KeeperCore.MainAssembly,
        historyEventMapper: HistoryEventMapper,
        filter: HistoryList.Filter,
        emptyViewProvider: ((HistoryList.Filter) -> HistoryListViewController.EmptyState?)?
    ) -> MVVMModule<HistoryListViewController, HistoryListModuleOutput, HistoryListModuleInput> {
        let viewModel = HistoryListViewModelImplementation(
            wallet: wallet,
            historyLoader: paginationLoader,
            dateFormatter: keeperCoreMainAssembly.formattersAssembly.dateFormatter,
            backgroundUpdate: keeperCoreMainAssembly.backgroundUpdateAssembly.backgroundUpdate,
            decryptedCommentStore: keeperCoreMainAssembly.storesAssembly.decryptedCommentStore,
            nftManagmentStore: keeperCoreMainAssembly.storesAssembly.walletNFTsManagementStore(wallet: wallet),
            appSettingsStore: keeperCoreMainAssembly.storesAssembly.appSettingsStore,
            transactionsManagementStore: keeperCoreMainAssembly.transactionsManagementAssembly.transactionsManagementStore(wallet: wallet),
            accountEventMapper: keeperCoreMainAssembly.mappersAssembly.historyAccountEventMapper,
            historyEventMapper: historyEventMapper,
            tronEventMapper: TronEventMapper(
                dateFormatter: keeperCoreMainAssembly.formattersAssembly.dateFormatter,
                amountFormatter: keeperCoreMainAssembly.formattersAssembly.signedAmountFormatter
            ),
            nftService: keeperCoreMainAssembly.servicesAssembly.nftService(),
            cacheProvider: cacheProvider,
            filter: filter
        )

        let viewController = HistoryListViewController(
            viewModel: viewModel,
            emptyViewProvider: emptyViewProvider
        )
        return .init(view: viewController, output: viewModel, input: viewModel)
    }
}
