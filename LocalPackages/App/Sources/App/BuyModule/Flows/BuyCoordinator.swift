import UIKit
import TKUIKit
import TKScreenKit
import TKCoordinator
import TKCore
import KeeperCore

public final class BuyCoordinator: RouterCoordinator<ViewControllerRouter> {
  
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
    let isBuySellLovely = coreAssembly.featureFlagsProvider.isBuySellLovely
    if isBuySellLovely {
      openBuySellList()
    } else {
      openUglyBuyList()
    }
  }
}

private extension BuyCoordinator {
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
  
  func openBuySellList() {
    let module = BuySellListAssembly.module(
      keeperCoreMainAssembly: keeperCoreMainAssembly,
      coreAssembly: coreAssembly
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
    
    module.output.didSelectCountryPicker = { [weak self, weak bottomSheetViewController] selectedCountry in
      guard let bottomSheetViewController else { return }
      self?.openCountryPicker(
        selectedCountry: selectedCountry,
        fromViewController: bottomSheetViewController,
        completion: { selectedCountry in
          module.input.setSelectedCountry(selectedCountry)
        }
      )
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
  
  func openWarning(item: BuySellItem, fromViewController: UIViewController) {
    let module = BuyListPopUpAssembly.module(
      buySellItemModel: item,
      appSettings: coreAssembly.appSettings,
      urlOpener: coreAssembly.urlOpener()
    )
    
    let bottomSheetViewController = TKBottomSheetViewController(contentViewController: module.view)
    bottomSheetViewController.present(fromViewController: fromViewController)
    
    module.output.didTapOpen = { [weak self, weak bottomSheetViewController] item in
      guard let bottomSheetViewController else { return }
      bottomSheetViewController.dismiss {
        self?.openWebView(url: item.actionUrl, fromViewController: fromViewController)
      }
    }
  }
  
  func openCountryPicker(selectedCountry: SelectedCountry,
                         fromViewController: UIViewController,
                         completion: @escaping (SelectedCountry) -> Void) {
    let countryPickerViewController = CountryPickerViewController(
      selectedCountry: selectedCountry,
      countriesProvider: CountriesProvider()
    )
    let bottomSheetViewController = TKBottomSheetViewController(contentViewController: countryPickerViewController)
    
    countryPickerViewController.didSelectCountry = { [weak bottomSheetViewController] in
      completion($0)
      bottomSheetViewController?.dismiss()
    }
    
    bottomSheetViewController.present(fromViewController: fromViewController)
  }
}
