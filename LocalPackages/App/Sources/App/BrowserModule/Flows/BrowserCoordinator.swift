import UIKit
import TKCoordinator
import TKUIKit
import TKScreenKit
import TKCore
import KeeperCore
import TonSwift
import TKLocalize

public final class BrowserCoordinator: RouterCoordinator<NavigationControllerRouter> {
  
  public var didHandleDeeplink: ((_ deeplink: Deeplink) -> Void)?
  
  private var browserInput: BrowserModuleInput?

  private let coreAssembly: TKCore.CoreAssembly
  private let keeperCoreMainAssembly: KeeperCore.MainAssembly
  
  public init(router: NavigationControllerRouter,
              coreAssembly: TKCore.CoreAssembly,
              keeperCoreMainAssembly: KeeperCore.MainAssembly) {
    self.coreAssembly = coreAssembly
    self.keeperCoreMainAssembly = keeperCoreMainAssembly
    super.init(router: router)
    router.rootViewController.tabBarItem.title = TKLocales.Tabs.browser
    router.rootViewController.tabBarItem.image = .TKUIKit.Icons.Size28.explore
  }
  
  public override func start() {
    openBrowser()
  }
  
  func openExplore() {
    browserInput?.openExplore()
  }
}

private extension BrowserCoordinator {

  func openBrowser() {
    let module = BrowserAssembly.module(keeperCoreAssembly: keeperCoreMainAssembly, coreAssembly: coreAssembly)
    
    module.output.didTapSearch = { [weak self] in
      self?.openSearch()
    }
    
    module.output.didSelectCategory = { [weak self] category in
      self?.openCategory(category)
    }
    
    module.output.didSelectDapp = { [weak self, unowned router] dapp in
      self?.openDapp(dapp, fromViewController: router.rootViewController)
    }

    module.output.didSelectCountryPicker = { [weak self] selectedCountry in
      guard let self = self else {
        return
      }
      
      self.openCountryPicker(selectedCountry: selectedCountry, fromViewController: router.rootViewController) { resultSelectedCountry in
        module.input.updateSelectedCountry(resultSelectedCountry)
      }
    }
    
    browserInput = module.input
    
    router.push(viewController: module.view, animated: false)
  }
  
  func openCategory(_ category: PopularAppsCategory) {
    let module = BrowserCategoryAssembly.module(category: category)
    
    module.output.didSelectDapp = { [weak self, unowned router] dapp in
      self?.openDapp(dapp, fromViewController: router.rootViewController)
    }
    
    module.output.didTapSearch = { [weak self] in
      self?.openSearch()
    }
    
    module.view.setupBackButton()
    
    router.push(viewController: module.view)
  }
  
  func openDapp(_ dapp: Dapp, fromViewController: UIViewController) {
    let router = ViewControllerRouter(rootViewController: fromViewController)
    let coordinator = DappCoordinator(
      router: router,
      dapp: dapp,
      coreAssembly: coreAssembly,
      keeperCoreMainAssembly: keeperCoreMainAssembly
    )
    
    coordinator.didHandleDeeplink = { [weak self] deeplink in
      _ = self?.didHandleDeeplink?(deeplink)
    }
    coordinator.didRequestOpenBuySell = { [weak self, weak coordinator] wallet in
      self?.removeChild(coordinator)
      self?.openBuySell(wallet: wallet, isInAppPurchase: true)
    }
    coordinator.didRequestOpenDefi = { [weak self, weak coordinator] wallet in
      guard let self else { return }

      self.removeChild(coordinator)
      self.openBuySell(wallet: wallet, isInAppPurchase: false)
    }

    addChild(coordinator)
    coordinator.start()
  }
  
  func openSearch() {
    let module = BrowserSearchAssembly.module(keeperCoreAssembly: keeperCoreMainAssembly)
    let navigationController = TKNavigationController(rootViewController: module.view)
    navigationController.configureDefaultAppearance()
    module.output.didSelectDapp = { [weak self, unowned navigationController] dapp in
      self?.openDapp(dapp, fromViewController: navigationController)
    }
    
    navigationController.modalTransitionStyle = .crossDissolve
    navigationController.modalPresentationStyle = .fullScreen
    router.present(navigationController)
  }

  func openCountryPicker(selectedCountry: SelectedCountry,
                         fromViewController: UIViewController,
                         completion: @escaping (SelectedCountry) -> Void) {
    let countryPickerViewController = CountryPickerViewController(
      selectedCountry: selectedCountry,
      countriesProvider: CountriesProvider()
    )
    let navigationController = TKNavigationController(rootViewController: countryPickerViewController)
    navigationController.setNavigationBarHidden(true, animated: false)

    countryPickerViewController.setupRightCloseButton { [weak navigationController] in
      navigationController?.dismiss(animated: true)
    }

    countryPickerViewController.didSelectCountry = { [weak navigationController] in
      completion($0)
      navigationController?.dismiss(animated: true)
    }

    fromViewController.present(navigationController, animated: true)
  }
}

public extension BrowserCoordinator {

  @MainActor
  func openBuySell(wallet: Wallet, isInAppPurchase: Bool) {
    let browserController = keeperCoreMainAssembly.browserExploreController()
    let lang = Locale.current.languageCode ?? "en"
    if !isInAppPurchase,
       let cachedCategories = try? browserController.getCachedPopularApps(lang: lang),
       let defiCategory = cachedCategories.categories.first(with: "defi", at: \.id) {

      self.openCategory(defiCategory)
      return
    }

    let coordinator = BuyCoordinator(
      wallet: wallet,
      keeperCoreMainAssembly: keeperCoreMainAssembly,
      coreAssembly: coreAssembly,
      router: ViewControllerRouter(rootViewController: router.rootViewController)
    )

    coordinator.didOpenItem = { [weak self] url, fromViewController in
      self?.openBuySellItemURL(url, fromViewController: fromViewController)
    }

    coordinator.didClose = { [weak coordinator, weak self] in
      self?.removeChild(coordinator)
    }

    router.dismiss(animated: true) { [weak self] in
      self?.addChild(coordinator)
      coordinator.start()
    }
  }

  private func openBuySellItemURL(_ url: URL, fromViewController: UIViewController) {
    let deeplinkHandler = TKWebViewControllerNavigationHandler { [weak self] deeplink in
      _ = self?.handleDeeplink(deeplink: deeplink)
    }
    let webViewController = TKWebViewController(url: url, handler: deeplinkHandler)
    let navigationController = UINavigationController(rootViewController: webViewController)
    navigationController.modalPresentationStyle = .fullScreen
    navigationController.configureTransparentAppearance()
    fromViewController.present(navigationController, animated: true)
  }
}
