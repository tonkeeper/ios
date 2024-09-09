import Foundation
import TKCore
import KeeperCore

struct StonfiSwapAssembly {
  private init() {}
  static func module(keeperCoreAssembly: KeeperCore.MainAssembly, messageHandler: StonfiSwapMessageHandler)
  -> MVVMModule<StonfiSwapViewController, Void, Void> {

    let viewModel = StonfiSwapViewModelImplementation(
      walletsStore: keeperCoreAssembly.storesAssembly.walletsStore,
      configurationStore: keeperCoreAssembly.configurationAssembly.remoteConfigurationStore,
      messageHandler: messageHandler
    )
    let viewController = StonfiSwapViewController(
      viewModel: viewModel
    )
    return .init(view: viewController, output: Void(), input: Void())
  }
}
