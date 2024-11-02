import UIKit
import TKCore
import KeeperCore

struct StakingInputAssembly {
  private init() {}
  
  static func module(configuration: StakingInputViewModelConfiguration,
                     detailsViewController: UIViewController,
                     keeperCoreMainAssembly: KeeperCore.MainAssembly,
                     coreAssembly: TKCore.CoreAssembly)
  -> MVVMModule<StakingInputViewController, StakingInputModuleOutput, StakingInputModuleInput> {
    let amountInput = AmountInputAssembly.module(
      sourceUnit: Token.ton,
      destinationUnit: Currency.USD,
      keeperCoreMainAssembly: keeperCoreMainAssembly
    )
    
    let viewModel = StakingInputViewModelImplementation(
      amountInputModuleInput: amountInput.input,
      amountInputModuleOutput: amountInput.output,
      viewModelConfiguration: configuration,
      currencyStore: keeperCoreMainAssembly.storesAssembly.currencyStore,
      tonRatesStore: keeperCoreMainAssembly.storesAssembly.tonRatesStore,
      configuration: keeperCoreMainAssembly.configurationAssembly.configuration,
      urlOpener: coreAssembly.urlOpener()
    )
    
    let viewController = StakingInputViewController(
      viewModel: viewModel,
      amountInputViewController: amountInput.view,
      detailsViewController: detailsViewController
    )
    
    return MVVMModule(view: viewController, output: viewModel, input: viewModel)
  }
}
