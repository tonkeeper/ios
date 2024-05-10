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
    //openBuyList()
    openBuySell()
  }
}

private extension BuyCoordinator {
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

  func openBuySell() {
    let module = BuySellAssembly.module(
      buySellController: keeperCoreMainAssembly.buySellController(
        wallet: wallet,
        isMarketRegionPickerAvailable: coreAssembly.featureFlagsProvider.isMarketRegionPickerAvailable
      ),
      appSettings: coreAssembly.appSettings,
      buySellItem: BuySellItem(
        operation: .buy,
        token: .ton,
        amount: 50
      )
    )
    
    module.view.setupRightCloseButton { [weak self] in
      self?.didFinish?()
    }
    
    module.view.didTapChangeCountryButton = {
      // TODO: Add Change Country Screen
      print("TODO: Add Change Country Screen")
    }
    
    module.output.didContinueBuySell = { [weak self] buySellOperation in
      self?.openOperator(buySellOperation: buySellOperation)
    }
    
    router.push(viewController: module.view, animated: false)
  }
  
  func openOperator(buySellOperation: BuySellOperationModel) {
    let module = FiatOperatorAssembly.module(
      fiatOperatorController: keeperCoreMainAssembly.fiatOperatorController(),
      buySellOperation: buySellOperation
    )
    
    module.view.setupBackButton()
    
    module.view.setupRightCloseButton { [weak self] in
      self?.didFinish?()
    }
    
    module.output.didTapCurrencyPicker = { [weak self, weak input = module.input, weak view = module.view] currencyListItem in
      self?.openCurrencyList(
        fromViewController: view,
        currencyListItem: currencyListItem,
        didChangeCurrencyClosure: input?.didChangeCurrency
      )
    }
    
    module.output.didTapContinue = {
      print("didTapContinue")
    }
    
    router.push(viewController: module.view, animated: true)
  }
  
  func openCurrencyList(fromViewController: UIViewController?,
                        currencyListItem: CurrencyListItem,
                        didChangeCurrencyClosure: ((Currency) -> Void)?) {
    let module = CurrencyListAssembly.module(
      currencyListController: keeperCoreMainAssembly.currencyListController(),
      currencyListItem: currencyListItem
    )
    
    module.view.setupRightCloseButton {
      fromViewController?.dismiss(animated: true)
    }
    
    module.output.didChangeCurrency = { newCurrency in
      didChangeCurrencyClosure?(newCurrency)
    }
    
    fromViewController?.present(module.view, animated: true)
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
