import UIKit
import TKUIKit
import TKScreenKit
import TKCoordinator
import TKCore
import KeeperCore

public final class BuyCoordinator: RouterCoordinator<NavigationControllerRouter> {
  
  var didFinish: (() -> Void)?
  
  private let wallet: Wallet
  private let keeperCoreMainAssembly: KeeperCore.MainAssembly
  private let coreAssembly: TKCore.CoreAssembly
  private let buyListController: BuyListController
  
  init(wallet: Wallet,
       keeperCoreMainAssembly: KeeperCore.MainAssembly,
       coreAssembly: TKCore.CoreAssembly,
       router: NavigationControllerRouter) {
    self.wallet = wallet
    self.keeperCoreMainAssembly = keeperCoreMainAssembly
    self.coreAssembly = coreAssembly
    self.buyListController = keeperCoreMainAssembly.buyListController(
      wallet: wallet,
      isMarketRegionPickerAvailable: coreAssembly.featureFlagsProvider.isMarketRegionPickerAvailable
    )
    super.init(router: router)
  }
  
  public override func start() {
    openBuyAndSell()
  }
}

private extension BuyCoordinator {
  func openBuyAndSell() {
    let module = BuyAndSellAssembly.module(
      buyListController: buyListController,
      tonRatesStore: keeperCoreMainAssembly.storesAssembly.tonRatesStore,
      bigIntAmountFormatter: keeperCoreMainAssembly.formattersAssembly.bigIntAmountFormatter(
        groupSeparator: ",",
        fractionalSeparator: "."
      )
    )
    
    module.view.setupRightCloseButton { [weak self] in
      self?.didFinish?()
    }
        
    module.output.didContinue = { [weak self] transactionModel in
      self?.openOperatorSelection(transactionModel: transactionModel)
    }
    
    router.push(viewController: module.view, animated: false)
  }
  
  func openOperatorSelection(transactionModel: TransactionAmountModel) {
    let module = OperatorSelectionAssembly.module(
      settingsController: keeperCoreMainAssembly.settingsController,
      buyListController: buyListController,
      currencyRateFormatter: keeperCoreMainAssembly.formattersAssembly.currencyToTONFormatter,
      currencyStore: keeperCoreMainAssembly.storesAssembly.currencyStore,
      transactionModel: transactionModel
    )
    
    module.view.setupBackButton()
    
    module.view.setupRightCloseButton { [weak self] in
      self?.didFinish?()
    }
    
    module.output.didTapCurrency = { [weak self] in
      self?.openCurrencyPicker()
    }
    
    module.output.didContinue = { [weak self] buySellItem, transactionModel, currency in
      self?.openTransactionAmountConfirmation(buySellItem: buySellItem, transactionModel: transactionModel, currency: currency)
    }
    
    router.push(viewController: module.view, animated: true)
  }
  
  func openTransactionAmountConfirmation(
    buySellItem: BuySellItemModel,
    transactionModel: TransactionAmountModel,
    currency: Currency
  ) {
    let module = TransactionAssembly.module(
      buySellItem: buySellItem,
      transactionModel: transactionModel,
      currency: currency,
      appSettings: coreAssembly.appSettings,
      buyListController: buyListController,
      currencyRateFormatter: keeperCoreMainAssembly.formattersAssembly.currencyToTONFormatter,
      bigIntAmountFormatter: keeperCoreMainAssembly.formattersAssembly.bigIntAmountFormatter(
        groupSeparator: ",",
        fractionalSeparator: "."
      )
    )
    
    let viewController = module.view
    
    module.view.setupRightCloseButton { [weak self] in
      self?.didFinish?()
    }
    
    module.view.setupBackButton()
    
    module.output.didContinueWithURL = { [weak self, weak viewController] url in
      guard let viewController else { return }
      
      self?.openWebView(url: url, fromViewController: viewController)
    }
    
    module.output.didContinueWithItem = { [weak self, weak viewController] item in
      guard let viewController else { return }
      
      self?.openWarning(item: item, fromViewController: viewController)
    }
    
    router.push(viewController: module.view, animated: true)
  }
  
  func openCurrencyPicker() {
    let itemsProvider = SettingsCurrencyPickerListItemsProvider(settingsController: keeperCoreMainAssembly.settingsController)
    let module = SettingsListAssembly.module(itemsProvider: itemsProvider, showsBackButton: false)
    let viewController = module.viewController

    let navigationController = TKNavigationController(rootViewController: viewController)
    navigationController.configureDefaultAppearance()
    
    viewController.setupRightCloseButton { [weak self] in
      self?.router.dismiss(animated: true)
    }
    
    router.present(navigationController, animated: true)
  }
  
  func openWebView(url: URL, fromViewController: UIViewController) {
    let webViewController = TKWebViewController(url: url)
    webViewController.setupBackButton()
    
    router.push(viewController: webViewController, animated: true)
  }
  
  func openWarning(item: BuySellItemModel, fromViewController: UIViewController) {
    let module = BuyListPopUpAssembly.module(
      buySellItemModel: item,
      appSettings: coreAssembly.appSettings,
      urlOpener: coreAssembly.urlOpener()
    )
    
    let bottomSheetViewController = TKBottomSheetViewController(contentViewController: module.view)
    bottomSheetViewController.present(fromViewController: fromViewController)
    
    module.output.didTapOpen = { [weak self, weak bottomSheetViewController] item in
      guard let bottomSheetViewController, let actionURL = item.actionURL else { return }
      bottomSheetViewController.dismiss {
        self?.openWebView(url: actionURL, fromViewController: fromViewController)
      }
    }
  }
}
