import AppUI
import KeeperCore
import SwiftUI
import TKUIKit
import UIKit

struct StakingRewardsHistoryAssembly {
    private init() {}

    @MainActor
    static func module(
        wallet: Wallet,
        keeperCoreMainAssembly: KeeperCore.MainAssembly
    ) -> (view: UIViewController, viewModel: StakingRewardsHistoryViewModel) {
        let amountFormatter = keeperCoreMainAssembly.formattersAssembly.amountFormatter
        let viewModel = StakingRewardsHistoryViewModel(
            wallet: wallet,
            stakingRewardsService: keeperCoreMainAssembly.servicesAssembly.stakingRewardsService(),
            rewardRowMapper: StakingRewardRowMapper(
                amountFormatter: amountFormatter,
                dateFormatter: keeperCoreMainAssembly.formattersAssembly.dateFormatter
            ),
            amountFormatter: amountFormatter,
            tonRatesStore: keeperCoreMainAssembly.storesAssembly.tonRatesStore,
            currencyStore: keeperCoreMainAssembly.storesAssembly.currencyStore,
            appSettingsStore: keeperCoreMainAssembly.storesAssembly.appSettingsStore
        )
        let viewController = TKHostingController(content: StakingRewardsHistoryScreen(viewModel: viewModel))
        viewModel.viewDidLoad()
        return (viewController, viewModel)
    }
}

private struct StakingRewardsHistoryScreen: View {
    @ObservedObject var viewModel: StakingRewardsHistoryViewModel

    var body: some View {
        StakingRewardsHistoryView(
            state: viewModel.state,
            onBack: { viewModel.didTapBack?() },
            onSelectPeriod: { viewModel.selectPeriod(index: $0) },
            onAppearRow: { viewModel.loadNextPageIfNeeded(row: $0) },
            onRefresh: { await viewModel.refresh() },
            onRetry: { viewModel.retry() }
        )
    }
}
