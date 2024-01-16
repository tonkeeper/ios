import Foundation
import TKUIKit
import UIKit
import KeeperCore

protocol WalletContainerModuleOutput: AnyObject {
  var didTapWalletButton: (() -> Void)? { get set }
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
  
  var didTapWalletButton: (() -> Void)?
  
  // MARK: - WalletContainerViewModel
  
  var didUpdateModel: ((WalletContainerView.Model) -> Void)?
  var didUpdateWalletBalanceViewController: ((_ viewController: UIViewController, _ animated: Bool) -> Void)?
  
  func viewDidLoad() {
    walletMainController.didUpdateActiveWallet = { [weak self] model in
      self?.didUpdateActiveWallet(model: model)
    }
    walletMainController.getActiveWallet()
    setupWalletBalance(animated: false)
  }
  
  // MARK: - Dependencies
  
  private let childModuleProvider: WalletContainerViewModelChildModuleProvider
  private let walletMainController: WalletMainController
  
  init(childModuleProvider: WalletContainerViewModelChildModuleProvider,
       walletMainController: WalletMainController) {
    self.childModuleProvider = childModuleProvider
    self.walletMainController = walletMainController
  }
}

private extension WalletContainerViewModelImplementation {
  func didUpdateActiveWallet(model: WalletMainController.WalletModel) {
    didUpdateModel?(createModel(walletModel: model))
  }
  
  func createModel(walletModel: WalletMainController.WalletModel) -> WalletContainerView.Model {
    let walletButtonModel = WalletContainerWalletButton.Model(
      title: walletModel.name,
      icon: .init(icon: .TKUIKit.Icons.Size16.chevronDown, position: .right)
    )
    
    let walletButtonAppearance = WalletContainerWalletButton.Appearance(
      backgroundColor: .Tint.color(with: walletModel.colorIdentifier),
      foregroundColor: .Icon.primary
    )
    
    let settingsButtonModel = TKUIHeaderAccentIconButton.Model(image: .TKUIKit.Icons.Size28.gear)
    
    let topBarViewModel = WalletContainerTopBarView.Model(
      walletButtonModel: walletButtonModel,
      walletButtonAppearance: walletButtonAppearance,
      settingsButtonModel: settingsButtonModel,
      walletButtonAction: { [weak self] in
        self?.didTapWalletButton?()
      }
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
