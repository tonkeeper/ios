import UIKit
import TKCore
import KeeperCore

struct TokenDetailsAssembly {
  private init() {}
  static func module(
    wallet: Wallet,
    balanceStore: ConvertedBalanceStoreV3,
    configurator: TokenDetailsConfigurator,
    tokenDetailsListContentViewController: TokenDetailsListContentViewController,
    chartViewControllerProvider: (() -> UIViewController?)?,
    hasAbout: Bool = false
  ) -> MVVMModule<TokenDetailsViewController, TokenDetailsModuleOutput, Void> {
    let viewModel = TokenDetailsViewModelImplementation(
      wallet: wallet,
      balanceStore: balanceStore,
      configurator: configurator,
      chartViewControllerProvider: chartViewControllerProvider
    )
    let viewController = TokenDetailsViewController(
      viewModel: viewModel,
      listContentViewController: tokenDetailsListContentViewController
    )
    return .init(view: viewController, output: viewModel, input: Void())
  }
}
