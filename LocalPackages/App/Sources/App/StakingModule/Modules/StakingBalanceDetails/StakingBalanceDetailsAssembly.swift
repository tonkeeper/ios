import Foundation
import TKCore
import KeeperCore

struct StakingBalanceDetailsAssembly {
  private init() {}
  
  static func module(wallet: Wallet,
                     stakingPoolInfo: StackingPoolInfo,
                     accountStackingInfo: AccountStackingInfo,
                     keeperCoreMainAssembly: KeeperCore.MainAssembly)
  -> MVVMModule<StakingBalanceDetailsViewController, StakingBalanceDetailsModuleOutput, StakingBalanceDetailsModuleOutput> {
    let viewModel = StakingBalanceDetailsViewModelImplementation(
      wallet: wallet,
      stakingPoolInfo: stakingPoolInfo,
      accountStackingInfo: accountStackingInfo,
      listViewModelBuilder: StakingListViewModelBuilder(
        decimalFormatter: keeperCoreMainAssembly.formattersAssembly.decimalAmountFormatter,
        amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter
      ),
      linksViewModelBuilder: StakingLinksViewModelBuilder(),
      balanceItemMapper: BalanceItemMapper(
        amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter,
        decimalAmountFormatter: keeperCoreMainAssembly.formattersAssembly.decimalAmountFormatter
      ),
      stakingPoolsStore: keeperCoreMainAssembly.storesAssembly.stackingPoolsStore,
      balanceStore: keeperCoreMainAssembly.mainStoresAssembly.processedBalanceStore,
      tonRatesStore: keeperCoreMainAssembly.storesAssembly.tonRatesStoreV2,
      currencyStore: keeperCoreMainAssembly.storesAssembly.currencyStoreV2,
      decimalFormatter: keeperCoreMainAssembly.formattersAssembly.decimalAmountFormatter,
      amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter
    )
    
    let viewController = StakingBalanceDetailsViewController(viewModel: viewModel)
    
    return MVVMModule(view: viewController, output: viewModel, input: viewModel)
  }
}
