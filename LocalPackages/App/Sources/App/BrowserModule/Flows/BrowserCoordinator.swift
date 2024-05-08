import UIKit
import TKCoordinator
import TKUIKit
import TKCore
import KeeperCore
import TonSwift
import TKLocalize

public final class BrowserCoordinator: RouterCoordinator<NavigationControllerRouter> {
  
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
    let module = BrowserAssembly.module(keeperCoreAssembly: keeperCoreMainAssembly)
    
    module.output.didTapSearch = { [weak self] in
      self?.openSearch()
    }
    
    module.output.didSelectCategory = { [weak self] category in
      self?.openCategory(category)
    }
    
    module.output.didSelectApp = { [weak self] app in
      self?.openApp(app)
    }
    
    router.push(viewController: module.view, animated: false)
  }
  
  func openCategory(_ category: PopularAppsCategory) {
    let module = BrowserCategoryAssembly.module(category: category)
    
    module.output.didSelectApp = { [weak self] app in
      self?.openApp(app)
    }
    
    module.view.setupBackButton()
    
    router.push(viewController: module.view)
  }
  
  func openApp(_ app: PopularApp) {
    
  }
  
  func openSearch() {
    
  }
}
