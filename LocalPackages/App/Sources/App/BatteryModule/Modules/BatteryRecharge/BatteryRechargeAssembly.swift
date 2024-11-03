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
    
    let amountInput = AmountInputAssembly.module(
      sourceUnit: token,
      destinationUnit: Currency.USD,
      keeperCoreMainAssembly: keeperCoreMainAssembly
    )
    
    let viewModel = BatteryRechargeViewModelImplementation(
      model: BatteryRechargeModel(
        token: token,
        wallet: wallet,
        balanceStore: keeperCoreMainAssembly.storesAssembly.balanceStore,
        currencyStore: keeperCoreMainAssembly.storesAssembly.currencyStore,
        tonRatesStore: keeperCoreMainAssembly.storesAssembly.tonRatesStore,
        batteryService: keeperCoreMainAssembly.batteryAssembly.batteryService(),
        configuration: keeperCoreMainAssembly.configurationAssembly.configuration
      ),
      configuration: configuration,
      amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter,
      decimalAmountFormatter: keeperCoreMainAssembly.formattersAssembly.decimalAmountFormatter,
      amountInputModuleInput: amountInput.input,
      amountInputModuleOutput: amountInput.output 
    )
    
    let viewController = BatteryRechargeViewController(viewModel: viewModel,
                                                       amountInputViewController: amountInput.view)
    
    return MVVMModule(
      view: viewController,
      output: viewModel,
      input: viewModel
    )
  }
}


