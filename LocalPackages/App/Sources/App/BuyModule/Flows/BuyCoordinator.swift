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
    openBuySell()
//    Task {
//      let isBuySellLovely = await coreAssembly.featureFlagsProvider.isBuySellLovely()
//      await MainActor.run {
//        if isBuySellLovely {
//          openBuyList()
//        } else {
//          openUglyBuyList()
//        }
//      }
//    }
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
      buySellModel: .buyTon(
        initialAmount: 50,
        minAmount: 50
      )
    )
    
    module.view.setupRightCloseButton { [weak self] in
      self?.didFinish?()
    }
    
    module.view.didTapChangeCountryButton = {
      // TODO: Add Change Country Screen
      print("TODO: Add Change Country Screen")
    }
    
    module.output.didContinueBuySell = { [weak self] buySellOperatorItem in
      self?.openBuySellOperator(buySellOperatorItem: buySellOperatorItem)
    }
    
    router.push(viewController: module.view, animated: false)
  }
  
  func openBuySellOperator(buySellOperatorItem: BuySellOperatorItem) {
    let module = BuySellOperatorAssembly.module(
      buySellOperatorController: keeperCoreMainAssembly.buySellOperatorController(
        fiatOperatorCategory: buySellOperatorItem.operation.fiatOperatorCategory
      ),
      buySellOperatorItem: buySellOperatorItem
    )
    
    module.view.setupBackButton()
    
    module.view.setupRightCloseButton { [weak self] in
      self?.didFinish?()
    }
    
    module.output.didTapCurrencyPicker = { [weak self, weak view = module.view, weak input = module.input] currencyListItem in
      self?.openCurrencyList(
        fromViewController: view,
        currencyListItem: currencyListItem,
        didChangeCurrencyClosure: input?.didChangeCurrency
      )
    }
    
    module.output.onOpenDetails = { [weak self] buySellDetailsItem, buySellTransactionModel in
      self?.openBuySellDetails(
        buySellDetailsItem: buySellDetailsItem,
        buySellTransactionModel: buySellTransactionModel
      )
    }
    
    module.output.onOpenProviderUrl = { [weak self, weak view = module.view] providerUrl in
      guard let providerUrl, let fromViewController = view else { return }
      self?.openBridgeWebView(titledUrl: providerUrl, fromViewController: fromViewController)
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
  
  func openBuySellDetails(buySellDetailsItem: BuySellDetailsItem, buySellTransactionModel: BuySellTransactionModel) {
    let module = BuySellDetailsAssembly.module(
      buySellDetailsController: keeperCoreMainAssembly.buySellDetailsController(),
      buySellDetailsItem: buySellDetailsItem,
      buySellTransactionModel: buySellTransactionModel
    )
    
    module.view.setupBackButton()
    
    module.view.setupRightCloseButton { [weak self] in
      self?.didFinish?()
    }
    
    module.output.didTapContinue = { [weak self, weak view = module.view] actionURL in
      guard let actionURL, let fromViewController = view else { return }
      self?.openBridgeWebView(titledUrl: actionURL, fromViewController: fromViewController)
    }
    
    module.output.didTapInfoButton = { [weak self, weak view = module.view] url in
      guard let url, let fromViewController = view else { return }
      self?.openBridgeWebView(titledUrl: url, fromViewController: fromViewController)
    }
    
    router.push(viewController: module.view, animated: true)
  }
  
  func openUglyBuyList() {
    let module = UglyBuyListAssembly.module(
      buyListController: keeperCoreMainAssembly.buyListController(
        wallet: wallet,
        isMarketRegionPickerAvailable: coreAssembly.featureFlagsProvider.isMarketRegionPickerAvailable
      ),
      appSettings: coreAssembly.appSettings
    )
    
    let bottomSheetViewController = TKBottomSheetViewController(contentViewController: module.view)
    module.output.didSelectURL = { [weak self, weak bottomSheetViewController] url in
      guard let bottomSheetViewController else { return }
      bottomSheetViewController.dismiss()
      self?.coreAssembly.urlOpener().open(url: url)
    }

    bottomSheetViewController.present(fromViewController: router.rootViewController)
  }
  
  func openBridgeWebView(titledUrl: TitledURL, fromViewController: UIViewController) {
    let bridgeWebViewController = TKBridgeWebViewController(
      initialURL: titledUrl.url,
      initialTitle: titledUrl.title,
      jsInjection: nil
    )
    bridgeWebViewController.modalPresentationStyle = .fullScreen
    fromViewController.present(bridgeWebViewController, animated: true)
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
