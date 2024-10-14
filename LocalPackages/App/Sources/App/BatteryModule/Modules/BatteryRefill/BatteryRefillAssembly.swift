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
        configurationStore: keeperCoreMainAssembly.configurationAssembly.configurationStore,
        tonRatesStore: keeperCoreMainAssembly.storesAssembly.tonRatesStore
      ),
      rechargeMethodsModel: BatteryRefillRechargeMethodsModel(
        wallet: wallet,
        balanceStore: keeperCoreMainAssembly.storesAssembly.convertedBalanceStore,
        configurationStore: keeperCoreMainAssembly.configurationAssembly.configurationStore,
        batteryService: keeperCoreMainAssembly.servicesAssembly.batteryService()
      ),
      headerModel: BatteryRefillHeaderModel(
        wallet: wallet,
        balanceStore: keeperCoreMainAssembly.storesAssembly.balanceStore,
        configurationStore: keeperCoreMainAssembly.configurationAssembly.configurationStore
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


