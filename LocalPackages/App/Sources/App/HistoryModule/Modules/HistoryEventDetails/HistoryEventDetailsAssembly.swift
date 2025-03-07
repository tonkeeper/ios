import Foundation
import TKCore
import KeeperCore

@MainActor
struct HistoryEventDetailsAssembly {
  private init() {}
  static func module(
    wallet: Wallet,
    event: AccountEventDetailsEvent,
    keeperCoreAssembly: KeeperCore.MainAssembly,
    urlOpener: URLOpener,
    isTestnet: Bool
  ) -> MVVMModule<HistoryEventDetailsViewController, HistoryEventDetailsModuleOutput, Void> {
    
    let transactionsManagementStore = keeperCoreAssembly.transactionsManagementAssembly.transactionsManagementStore(wallet: wallet)
    
    let mapper = HistoryEventDetailsMapper(
      wallet: wallet,
      amountMapper: SignedAccountEventAmountMapper(
        plainAccountEventAmountMapper: PlainAccountEventAmountMapper(
          amountFormatter: keeperCoreAssembly.formattersAssembly.amountFormatter
        )
      ),
      balanceStore: keeperCoreAssembly.storesAssembly.balanceStore,
      tonRatesStore: keeperCoreAssembly.storesAssembly.tonRatesStore,
      currencyStore: keeperCoreAssembly.storesAssembly.currencyStore,
      nftService: keeperCoreAssembly.servicesAssembly.nftService(),
      nftManagmentStore: keeperCoreAssembly.storesAssembly.walletNFTsManagementStore(wallet: wallet),
      transactionsManagementStore: transactionsManagementStore,
      isTestnet: isTestnet,
      configuration: keeperCoreAssembly.configurationAssembly.configuration
    )
    
    let viewModel = HistoryEventDetailsViewModelImplementation(
      wallet: wallet,
      event: event,
      historyEventDetailsMapper: mapper,
      decryptedCommentStore: keeperCoreAssembly.storesAssembly.decryptedCommentStore,
      transactionsManagementStore: transactionsManagementStore
    )
    let viewController = HistoryEventDetailsViewController(viewModel: viewModel)
    return .init(view: viewController, output: viewModel, input: Void())
  }
}
