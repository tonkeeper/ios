import UIKit
import TKCore
import KeeperCore

struct BatteryRechargeAssembly {
  private init() {}
  static func module(wallet: Wallet,
                     token: Token,
                     rate: NSDecimalNumber?,
                     configuration: BatteryRechargeViewModelConfiguration,
                     keeperCoreMainAssembly: KeeperCore.MainAssembly,
                     coreAssembly: TKCore.CoreAssembly) -> MVVMModule<BatteryRechargeViewController, BatteryRechargeModuleOutput, BatteryRechargeModuleInput> {
    let viewModel = BatteryRechargeViewModelImplementation(
      model: BatteryRechargeModel(
        token: token,
        rate: rate,
        wallet: wallet,
        balanceStore: keeperCoreMainAssembly.storesAssembly.balanceStore,
        currencyStore: keeperCoreMainAssembly.storesAssembly.currencyStore,
        tonRatesStore: keeperCoreMainAssembly.storesAssembly.tonRatesStore,
        configurationStore: keeperCoreMainAssembly.configurationAssembly.configurationStore
      ),
      configuration: configuration,
      amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter,
      decimalAmountFormatter: keeperCoreMainAssembly.formattersAssembly.decimalAmountFormatter
    )
    
    let viewController = BatteryRechargeViewController(viewModel: viewModel)
    
    return MVVMModule(
      view: viewController,
      output: viewModel,
      input: viewModel
    )
  }
}


