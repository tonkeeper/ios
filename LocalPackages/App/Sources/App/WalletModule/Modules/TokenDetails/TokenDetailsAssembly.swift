import KeeperCore
import TKCore
import UIKit

struct TokenDetailsAssembly {
    private init() {}
    static func module(
        wallet: Wallet,
        balanceLoader: BalanceLoader,
        balanceStore: ProcessedBalanceStore,
        appSettingsStore: AppSettingsStore,
        configurator: TokenDetailsConfigurator,
        tokenDetailsListContentViewController: TokenDetailsListContentViewController,
        chartViewControllerProvider: (() -> UIViewController?)?,
        hasAbout: Bool = false
    ) -> MVVMModule<TokenDetailsViewController, TokenDetailsModuleOutput, Void> {
        let viewModel = TokenDetailsViewModelImplementation(
            wallet: wallet,
            balanceLoader: balanceLoader,
            balanceStore: balanceStore,
            appSettingsStore: appSettingsStore,
            configurator: configurator,
            chartViewControllerProvider: chartViewControllerProvider
        )
        let viewController = TokenDetailsViewController(
            viewModel: viewModel,
            listContentViewController: tokenDetailsListContentViewController
        )
        return .init(view: viewController, output: viewModel, input: ())
    }
}
