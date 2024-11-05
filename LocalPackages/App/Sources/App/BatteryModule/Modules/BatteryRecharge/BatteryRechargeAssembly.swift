import UIKit
import TKCore
import KeeperCore

struct BatteryRechargeAssembly {
  private init() {}
  static func module(wallet: Wallet,
                     token: Token,
                     isGift: Bool,
                     promocodeStore: BatteryPromocodeStore,
                     keeperCoreMainAssembly: KeeperCore.MainAssembly,
                     coreAssembly: TKCore.CoreAssembly) -> MVVMModule<BatteryRechargeViewController, BatteryRechargeModuleOutput, BatteryRechargeModuleInput> {
    
    let promocodeInput = BatteryPromocodeInputAssembly.module(
      wallet: wallet,
      promocodeStore: promocodeStore,
      keeperCoreMainAssembly: keeperCoreMainAssembly,
      coreAssembly: coreAssembly
    )
    
    let recipientInput = RecipientInputAssembly.module(
      wallet: wallet,
      keeperCoreMainAssembly: keeperCoreMainAssembly,
      coreAssembly: coreAssembly
    )
    
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
        configuration: keeperCoreMainAssembly.configurationAssembly.configuration,
        isGift: isGift
      ),
      amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter,
      decimalAmountFormatter: keeperCoreMainAssembly.formattersAssembly.decimalAmountFormatter,
      amountInputModuleInput: amountInput.input,
      amountInputModuleOutput: amountInput.output,
      promocodeOutput: promocodeInput.output,
      recipientInputOutput: recipientInput.output
    )
    
    let viewController = BatteryRechargeViewController(
      viewModel: viewModel,
      amountInputViewController: amountInput.view,
      promocodeViewController: promocodeInput.view,
      recipientViewController: recipientInput.view
    )
    
    return MVVMModule(
      view: viewController,
      output: viewModel,
      input: viewModel
    )
  }
}


