import Foundation
import TKCore
import KeeperCore

struct SendV3Assembly {
  private init() {}
  static func module(wallet: Wallet,
                     item: SendV3Item,
                     recipient: Recipient?,
                     comment: String?,
                     coreAssembly: TKCore.CoreAssembly,
                     keeperCoreMainAssembly: KeeperCore.MainAssembly) -> MVVMModule<SendV3ViewController, SendV3ModuleOutput, SendV3ModuleInput> {
    let viewModel = SendV3ViewModelImplementation(
      wallet: wallet,
      item: item,
      recipient: recipient,
      comment: comment,
      sendController: keeperCoreMainAssembly.sendV3Controller(wallet: wallet),
      balanceStore: keeperCoreMainAssembly.storesAssembly.convertedBalanceStore,
      appSettingsStore: keeperCoreMainAssembly.storesAssembly.appSettingsStore,
      buySellMethodsService: keeperCoreMainAssembly.buySellAssembly.buySellMethodsService()
    )
    let viewController = SendV3ViewController(viewModel: viewModel)
    return .init(view: viewController, output: viewModel, input: viewModel)
  }
}
