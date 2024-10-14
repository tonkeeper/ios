import Foundation
import UIKit
import TKCore
import KeeperCore

struct ChooseWalletToAddAssembly {
  private init() {}
  static func module(activeWalletModels: [ActiveWalletModel],
                     configuration: ChooseWalletToAddConfiguration,
                     amountFormatter: AmountFormatter,
                     isTestnet: Bool) -> MVVMModule<UIViewController, ChooseWalletToAddModuleOutput, Void> {
    let viewModel = ChooseWalletToAddViewModelImplementation(
      activeWalletModels: activeWalletModels,
      amountFormatter: amountFormatter,
      configuration: configuration,
      isTestnet: isTestnet
    )
    let viewController = ChooseWalletToAddViewController(viewModel: viewModel)
    return .init(view: viewController, output: viewModel, input: Void())
  }
}
