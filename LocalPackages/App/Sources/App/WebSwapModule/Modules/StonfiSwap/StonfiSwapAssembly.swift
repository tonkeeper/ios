import Foundation
import TKCore
import KeeperCore

struct StonfiSwapAssembly {
  private init() {}
  static func module(wallet: Wallet,
                     fromToken: String? = nil,
                     toToken: String? = nil,
                     keeperCoreAssembly: KeeperCore.MainAssembly,
                     messageHandler: StonfiSwapMessageHandler)
  -> MVVMModule<StonfiSwapViewController, Void, Void> {

    let viewModel = StonfiSwapViewModelImplementation(
      wallet: wallet,
      configurationStore: keeperCoreAssembly.configurationAssembly.remoteConfigurationStore,
      messageHandler: messageHandler,
      fromToken: fromToken,
      toToken: toToken
    )
    let viewController = StonfiSwapViewController(
      viewModel: viewModel
    )
    return .init(view: viewController, output: Void(), input: Void())
  }
}
