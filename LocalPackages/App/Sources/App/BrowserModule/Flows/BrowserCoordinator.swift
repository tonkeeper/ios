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
