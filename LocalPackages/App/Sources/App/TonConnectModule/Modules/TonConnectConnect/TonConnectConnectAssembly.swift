import UIKit
import TKCore
import KeeperCore

struct TonConnectConnectAssembly {
  private init() {}
  static func module(
    parameters: TonConnectParameters,
    manifest: TonConnectManifest,
    walletsStore: WalletsStoreV3,
    showWalletPicker: Bool
  ) -> MVVMModule<
    TonConnectConnectViewController,
    TonConnectConnectViewModuleOutput,
    TonConnectConnectModuleInput
  > {
    let viewModel = TonConnectConnectViewModelImplementation(
      parameters: parameters,
      manifest: manifest,
      walletsStore: walletsStore,
      showWalletPicker: showWalletPicker
    )
    let viewController = TonConnectConnectViewController(viewModel: viewModel)
    return .init(view: viewController, output: viewModel, input: viewModel)
  }
}
