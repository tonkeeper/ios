import Foundation
import TKCore
import KeeperCore
import TronSwift

@MainActor
struct HistoryEventDetailsAssembly {
  private init() {}
  static func module(
    wallet: Wallet,
    event: HistoryEventDetailsEvent,
    keeperCoreAssembly: KeeperCore.MainAssembly,
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
      tonviewerURLBuilder: TonviewerURLBuilder(configuration: keeperCoreAssembly.configurationAssembly.configuration),
      isTestnet: isTestnet,
      configuration: keeperCoreAssembly.configurationAssembly.configuration
    )
    
    let tronMapper = HistoryEventDetailsTronMapper(
      wallet: wallet,
      amountMapper: SignedAccountEventAmountMapper(
        plainAccountEventAmountMapper: PlainAccountEventAmountMapper(
          amountFormatter: keeperCoreAssembly.formattersAssembly.amountFormatter
        )
      ),
      tonRatesStore: keeperCoreAssembly.storesAssembly.tonRatesStore,
      currencyStore: keeperCoreAssembly.storesAssembly.currencyStore,
      isTestnet: isTestnet,
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
    return .init(view: viewController, output: viewModel, input: Void())
  }
}
