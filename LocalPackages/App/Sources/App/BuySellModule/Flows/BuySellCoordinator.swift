import UIKit
import TKUIKit
import TKScreenKit
import TKCoordinator
import TKCore
import KeeperCore

public final class BuySellCoordinator: RouterCoordinator<ViewControllerRouter> {
  
  private let wallet: Wallet
  private let keeperCoreMainAssembly: KeeperCore.MainAssembly
  private let coreAssembly: TKCore.CoreAssembly
  
  init(wallet: Wallet,
       keeperCoreMainAssembly: KeeperCore.MainAssembly,
       coreAssembly: TKCore.CoreAssembly,
       router: ViewControllerRouter) {
    self.wallet = wallet
    self.keeperCoreMainAssembly = keeperCoreMainAssembly
    self.coreAssembly = coreAssembly
    super.init(router: router)
  }
  
  public override func start() {
    openBuySellAmount()
  }
}

private extension BuySellCoordinator {
  func openBuySellAmount() {
    let module = BuySellAmountAssembly.module(
      buySellAmountController: keeperCoreMainAssembly.buySellAmountController(
        token: Token.ton,
        tokenAmount: 0,
        wallet: wallet,
        isMarketRegionPickerAvailable: {
          true // TODO::
        }
      )
    )
    
    let nav = TKNavigationController(rootViewController: module.view)
    module.output.onOpenCurrencyPicker = { [weak self] items, selectedItem in
      self?.openCurrencyPicker(on: nav, onCompletion: { newItem in
        DispatchQueue.main.async {
          module.input.updateCurrency(to: newItem)
          nav.popViewController(animated: true)
        }
      })
    }
    
    module.output.didFinish = { [weak self] fiatMethods, operators, selectedCurrency, rates, amount, isBuying in
      self?.openOperatorPicker(on: nav,
                               fiatMethods: fiatMethods,
                               operators: operators,
                               selectedCurrency: selectedCurrency,
                               rates: rates,
                               amount: amount,
                               isBuying: isBuying)
    }
    
    router.rootViewController.present(nav, animated: true)
  }
  
  func openCurrencyPicker(on nav: UINavigationController, onCompletion: ((String) -> Void)?) {
    let itemsProvider = SettingsCurrencyPickerListItemsProvider(settingsController: keeperCoreMainAssembly.settingsController)
    //let itemsProvider = BuySellCurrencyListItemsProvider(items: items, selectedItem: selectedItem)
    let module = SettingsListAssembly.module(itemsProvider: itemsProvider)
    
    module.output.didSelectAnItem = { item in
      onCompletion?(item)
    }
    
    nav.pushViewController(module.viewController, animated: true)
  }
  
  func openOperatorPicker(on nav: UINavigationController,
                          fiatMethods: FiatMethods,
                          operators: [BuySellItemModel],
                          selectedCurrency: String,
                          rates: BuySellRateItemsResponse,
                          amount: Double,
                          isBuying: Bool) {
    let operatorViewController = BuySellOperatorViewController(fiatMethods: fiatMethods,
                                                               operators: operators,
                                                               selectedCurrency: selectedCurrency,
                                                               rates: rates,
                                                               amount: amount,
                                                               isBuying: isBuying)
    nav.pushViewController(operatorViewController, animated: true)
  }
}
