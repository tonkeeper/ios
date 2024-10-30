import UIKit
import TKCore
import KeeperCore

struct BatteryRefillAssembly {
  private init() {}
  static func module(wallet: Wallet,
                     keeperCoreMainAssembly: KeeperCore.MainAssembly,
                     coreAssembly: TKCore.CoreAssembly) -> MVVMModule<BatteryRefillViewController, BatteryRefillModuleOutput, BatteryRefillModuleInput> {
    let viewModel = BatteryRefillViewModelImplementation(
      inAppPurchaseModel: BatteryRefillIAPModel(
        wallet: wallet,
        balanceStore: keeperCoreMainAssembly.storesAssembly.balanceStore,
        configuration: keeperCoreMainAssembly.configurationAssembly.configuration,
        tonRatesStore: keeperCoreMainAssembly.storesAssembly.tonRatesStore
      ),
      rechargeMethodsModel: BatteryRefillRechargeMethodsModel(
        wallet: wallet,
        balanceStore: keeperCoreMainAssembly.storesAssembly.convertedBalanceStore,
        configuration: keeperCoreMainAssembly.configurationAssembly.configuration,
        batteryService: keeperCoreMainAssembly.batteryAssembly.batteryService()
      ),
      headerModel: BatteryRefillHeaderModel(
        wallet: wallet,
        balanceStore: keeperCoreMainAssembly.storesAssembly.balanceStore,
        configuration: keeperCoreMainAssembly.configurationAssembly.configuration
      ),
      decimalAmountFormatter: keeperCoreMainAssembly.formattersAssembly.decimalAmountFormatter,
      amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter
    )
    
    let viewController = BatteryRefillViewController(viewModel: viewModel)
    
    return MVVMModule(
      view: viewController,
      output: viewModel,
      input: viewModel
    )
  }
}


