import UIKit
import TKUIKit
import TKScreenKit
import TKCoordinator
import TKCore
import KeeperCore

public final class BuyCoordinator: RouterCoordinator<ViewControllerRouter> {
  
  var didOpenItem: ((URL, _ fromViewController: UIViewController) -> Void)?
  
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
    openBuySellList()
  }
}

private extension BuyCoordinator {
  func openBuySellList() {
    let module = BuySellListAssembly.module(
      wallet: wallet,
      keeperCoreMainAssembly: keeperCoreMainAssembly,
      coreAssembly: coreAssembly
    )
    
    let bottomSheetViewController = TKBottomSheetViewController(contentViewController: module.view)
    
    module.output.didSelectURL = { [weak self, weak bottomSheetViewController] url in
      guard let bottomSheetViewController else { return }
      self?.didOpenItem?(url, bottomSheetViewController)
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
        self?.didOpenItem?(item.actionUrl, fromViewController)
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
