import Foundation
import TKCore
import KeeperCore

struct TokenPickerAssembly {
  private init() {}
  static func module(wallet: Wallet,
                     selectedToken: Token,
                     keeperCoreMainAssembly: KeeperCore.MainAssembly,
                     coreAssembly: TKCore.CoreAssembly) -> MVVMModule<TokenPickerViewController, TokenPickerModuleOutput, Void> {
    let viewModel = TokenPickerViewModelImplementation(
      tokenPickerModel: TokenPickerModel(
        wallet: wallet,
        selectedToken: selectedToken,
        balanceStore: keeperCoreMainAssembly.mainStoresAssembly.convertedBalanceStore
      ),
      amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter
    )
    let viewController = TokenPickerViewController(viewModel: viewModel)
    return .init(view: viewController, output: viewModel, input: Void())
  }
}
