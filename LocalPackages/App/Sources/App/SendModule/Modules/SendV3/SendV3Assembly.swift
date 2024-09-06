import Foundation
import TKCore
import KeeperCore

struct SendV3Assembly {
  private init() {}
  static func module(wallet: Wallet,
                     sendItem: SendItem,
                     recipient: Recipient?,
                     coreAssembly: TKCore.CoreAssembly,
                     keeperCoreMainAssembly: KeeperCore.MainAssembly) -> MVVMModule<SendV3ViewController, SendV3ModuleOutput, SendV3ModuleInput> {
    let viewModel = SendV3ViewModelImplementation(
      wallet: wallet,
      sendItem: sendItem,
      recipient: recipient,
      sendController: keeperCoreMainAssembly.sendV3Controller(wallet: wallet),
      balanceStore: keeperCoreMainAssembly.storesAssembly.convertedBalanceStore
    )
    let viewController = SendV3ViewController(viewModel: viewModel)
    return .init(view: viewController, output: viewModel, input: viewModel)
  }
}
