import Foundation
import TKUIKit
import UIKit

protocol WalletContainerModuleOutput: AnyObject {

}

protocol WalletContainerViewModel: AnyObject {
  var didUpdateModel: ((WalletContainerView.Model) -> Void)? { get set }
  var didUpdateWalletBalanceViewController: ((_ viewController: UIViewController, _ animated: Bool) -> Void)? { get set }
  
  func viewDidLoad()
}

protocol WalletContainerViewModelChildModuleProvider {
  func getWalletBalanceModuleView() -> UIViewController
}

final class WalletContainerViewModelImplementation: WalletContainerViewModel, WalletContainerModuleOutput {
  
  // MARK: - WalletContainerModuleOutput
  
  // MARK: - WalletContainerViewModel
  
  var didUpdateModel: ((WalletContainerView.Model) -> Void)?
  var didUpdateWalletBalanceViewController: ((_ viewController: UIViewController, _ animated: Bool) -> Void)?
  
  func viewDidLoad() {
    didUpdateModel?(createModel())
    setupWalletBalance(animated: false)
  }
  
  // MARK: - Dependencies
  
  private let childModuleProvider: WalletContainerViewModelChildModuleProvider
  
  init(childModuleProvider: WalletContainerViewModelChildModuleProvider) {
    self.childModuleProvider = childModuleProvider
  }
}

private extension WalletContainerViewModelImplementation {
  func createModel() -> WalletContainerView.Model {
    let walletButtonModel = WalletContainerWalletButton.Model(
      title: "🙃 Wallet",
      icon: .init(icon: .TKUIKit.Icons.Size16.chevronDown, position: .right)
    )
    
    let walletButtonAppearance = WalletContainerWalletButton.Appearance(
      backgroundColor: .Tint.color1,
      foregroundColor: .Icon.primary
    )
    
    let settingsButtonModel = TKUIHeaderAccentIconButton.Model(image: .TKUIKit.Icons.Size28.gear)
    
    let topBarViewModel = WalletContainerTopBarView.Model(
      walletButtonModel: walletButtonModel,
      walletButtonAppearance: walletButtonAppearance,
      settingsButtonModel: settingsButtonModel
    )
    
    return WalletContainerView.Model(
      topBarViewModel: topBarViewModel
    )
  }
  
  func setupWalletBalance(animated: Bool) {
    let viewController = childModuleProvider.getWalletBalanceModuleView()
    didUpdateWalletBalanceViewController?(viewController, animated)
  }
}
