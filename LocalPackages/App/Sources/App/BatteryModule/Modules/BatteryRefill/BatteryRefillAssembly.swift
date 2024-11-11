import UIKit
import TKCore
import KeeperCore

struct BatteryRefillAssembly {
  private init() {}
  static func module(wallet: Wallet,
                     promocodeStore: BatteryPromocodeStore,
                     keeperCoreMainAssembly: KeeperCore.MainAssembly,
                     coreAssembly: TKCore.CoreAssembly) -> MVVMModule<BatteryRefillViewController, BatteryRefillModuleOutput, BatteryRefillModuleInput> {
    
    let promocodeInput = BatteryPromocodeInputAssembly.module(
      wallet: wallet,
      promocodeStore: promocodeStore,
      keeperCoreMainAssembly: keeperCoreMainAssembly,
      coreAssembly: coreAssembly
    )
    
    let viewModel = BatteryRefillViewModelImplementation(
      wallet: wallet,
      inAppPurchaseModel: BatteryRefillIAPModel(
        wallet: wallet,
        batteryService: keeperCoreMainAssembly.batteryAssembly.batteryService(),
        tonProofService: keeperCoreMainAssembly.servicesAssembly.tonProofTokenService(),
        balanceStore: keeperCoreMainAssembly.storesAssembly.balanceStore,
        configuration: keeperCoreMainAssembly.configurationAssembly.configuration,
        tonRatesStore: keeperCoreMainAssembly.storesAssembly.tonRatesStore,
        balanceLoader: keeperCoreMainAssembly.loadersAssembly.balanceLoader
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
      tonProofTokenService: keeperCoreMainAssembly.servicesAssembly.tonProofTokenService(),
      configuration: keeperCoreMainAssembly.configurationAssembly.configuration,
      decimalAmountFormatter: keeperCoreMainAssembly.formattersAssembly.decimalAmountFormatter,
      amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter,
      promocodeOutput: promocodeInput.output
    )
    
    let viewController = BatteryRefillViewController(
      viewModel: viewModel,
      promocodeViewController: promocodeInput.view
    )
    
    return MVVMModule(
      view: viewController,
      output: viewModel,
      input: viewModel
    )
  }
}


