import Foundation
import TKCore
import KeeperCore

struct HistoryEventDetailsAssembly {
  private init() {}
  static func module(
    wallet: Wallet,
    event: AccountEventDetailsEvent,
    keeperCoreAssembly: KeeperCore.MainAssembly,
    urlOpener: URLOpener,
    isTestnet: Bool
  ) -> MVVMModule<HistoryEventDetailsViewController, HistoryEventDetailsModuleOutput, Void> {
    let mapper = HistoryEventDetailsMapper(
      amountMapper: SignedAccountEventAmountMapper(
        plainAccountEventAmountMapper: PlainAccountEventAmountMapper(
          amountFormatter: keeperCoreAssembly.formattersAssembly.amountFormatter
        )
      ),
      tonRatesStore: keeperCoreAssembly.storesAssembly.tonRatesStore,
      currencyStore: keeperCoreAssembly.storesAssembly.currencyStore,
      nftService: keeperCoreAssembly.servicesAssembly.nftService(),
      isTestnet: isTestnet
    )
    
    let viewModel = HistoryEventDetailsViewModelImplementation(
      wallet: wallet,
      event: event,
      historyEventDetailsMapper: mapper,
      urlOpener: urlOpener,
      configurationStore: keeperCoreAssembly.configurationAssembly.configurationStore,
      decryptedCommentStore: keeperCoreAssembly.storesAssembly.decryptedCommentStore
    )
    let viewController = HistoryEventDetailsViewController(viewModel: viewModel)
    return .init(view: viewController, output: viewModel, input: Void())
  }
}
