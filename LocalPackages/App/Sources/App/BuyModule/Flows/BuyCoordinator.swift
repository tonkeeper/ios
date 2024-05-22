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
  
  init(wallet: Wallet,
       keeperCoreMainAssembly: KeeperCore.MainAssembly,
       coreAssembly: TKCore.CoreAssembly,
       router: NavigationControllerRouter) {
    self.wallet = wallet
    self.keeperCoreMainAssembly = keeperCoreMainAssembly
    self.coreAssembly = coreAssembly
    super.init(router: router)
  }
  
  public override func start() {
    openBuyAndSell()
  }
}

private extension BuyCoordinator {
  func openBuyAndSell() {
    let module = BuyAndSellAssembly.module(
      buyListController: keeperCoreMainAssembly.buyListController(
        wallet: wallet,
        isMarketRegionPickerAvailable: coreAssembly.featureFlagsProvider.isMarketRegionPickerAvailable
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
      buyListController: keeperCoreMainAssembly.buyListController(
        wallet: wallet,
        isMarketRegionPickerAvailable: coreAssembly.featureFlagsProvider.isMarketRegionPickerAvailable
      ), 
      decimalAmountFormatter: keeperCoreMainAssembly.formattersAssembly.decimalAmountFormatter,
      currencyStore: keeperCoreMainAssembly.storesAssembly.currencyStore,
      transactionModel: transactionModel
    )
    
    module.view.setupRightCloseButton { [weak self] in
      self?.didFinish?()
    }
    
    module.view.setupBackButton()
    
    module.output.didTapCurrency = { [weak self] in
      self?.openCurrencyPicker()
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
  
  func openBuyList() {
    let module = BuyListAssembly.module(
      buyListController: keeperCoreMainAssembly.buyListController(
        wallet: wallet,
        isMarketRegionPickerAvailable: coreAssembly.featureFlagsProvider.isMarketRegionPickerAvailable
      ),
      appSettings: coreAssembly.appSettings
    )
    
    let bottomSheetViewController = TKBottomSheetViewController(contentViewController: module.view)
    
    module.output.didSelectURL = { [weak self, weak bottomSheetViewController] url in
      guard let bottomSheetViewController else { return }
      self?.openWebView(url: url, fromViewController: bottomSheetViewController)
    }
    
    module.output.didSelectItem = { [weak self, weak bottomSheetViewController] item in
      guard let bottomSheetViewController else { return }
      self?.openWarning(item: item, fromViewController: bottomSheetViewController)
    }
    
    bottomSheetViewController.present(fromViewController: router.rootViewController)
  }
  
  func openWebView(url: URL, fromViewController: UIViewController) {
    let webViewController = TKWebViewController(url: url)
    let navigationController = UINavigationController(rootViewController: webViewController)
    navigationController.modalPresentationStyle = .fullScreen
    navigationController.configureTransparentAppearance()
    fromViewController.present(navigationController, animated: true)
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
