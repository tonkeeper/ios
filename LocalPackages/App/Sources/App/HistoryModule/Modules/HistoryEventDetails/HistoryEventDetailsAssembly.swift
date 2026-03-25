import Foundation
import KeeperCore
import TKCore
import TronSwift

@MainActor
struct HistoryEventDetailsAssembly {
    private init() {}
    static func module(
        wallet: Wallet,
        event: HistoryEventDetailsEvent,
        keeperCoreAssembly: KeeperCore.MainAssembly,
        network: Network
    ) -> MVVMModule<HistoryEventDetailsViewController, HistoryEventDetailsModuleOutput, Void> {
        let transactionsManagementStore = keeperCoreAssembly.transactionsManagementAssembly.transactionsManagementStore(wallet: wallet)

        let mapper = HistoryEventDetailsMapper(
            wallet: wallet,
            amountFormatter: keeperCoreAssembly.formattersAssembly.amountFormatter,
            signedAmountFormatter: keeperCoreAssembly.formattersAssembly.signedAmountFormatter,
            balanceStore: keeperCoreAssembly.storesAssembly.balanceStore,
            tonRatesStore: keeperCoreAssembly.storesAssembly.tonRatesStore,
            currencyStore: keeperCoreAssembly.storesAssembly.currencyStore,
            nftService: keeperCoreAssembly.servicesAssembly.nftService(),
            nftManagmentStore: keeperCoreAssembly.storesAssembly.walletNFTsManagementStore(wallet: wallet),
            transactionsManagementStore: transactionsManagementStore,
            tonviewerURLBuilder: TonviewerURLBuilder(configuration: keeperCoreAssembly.configurationAssembly.configuration),
            network: network,
            configuration: keeperCoreAssembly.configurationAssembly.configuration
        )

        let tronMapper = HistoryEventDetailsTronMapper(
            wallet: wallet,
            amountFormatter: keeperCoreAssembly.formattersAssembly.amountFormatter,
            tonRatesStore: keeperCoreAssembly.storesAssembly.tonRatesStore,
            currencyStore: keeperCoreAssembly.storesAssembly.currencyStore,
            network: network,
            configuration: keeperCoreAssembly.configurationAssembly.configuration
        )

        let viewModel = HistoryEventDetailsViewModelImplementation(
            wallet: wallet,
            event: event,
            historyEventDetailsMapper: mapper,
            historyEventDetailsTronMapper: tronMapper,
            decryptedCommentStore: keeperCoreAssembly.storesAssembly.decryptedCommentStore,
            transactionsManagementStore: transactionsManagementStore
        )
        let viewController = HistoryEventDetailsViewController(viewModel: viewModel)
        return .init(view: viewController, output: viewModel, input: ())
    }
}
