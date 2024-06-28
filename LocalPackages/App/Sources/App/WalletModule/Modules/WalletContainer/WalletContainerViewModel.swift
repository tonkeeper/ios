import Foundation
import TKUIKit
import UIKit
import KeeperCore

protocol WalletContainerModuleOutput: AnyObject {
  var walletButtonHandler: (() -> Void)? { get set }
  var didTapSettingsButton: (() -> Void)? { get set }
}

protocol WalletContainerViewModel: AnyObject {
  var didUpdateModel: ((WalletContainerView.Model) -> Void)? { get set }
  var didUpdateWalletBalanceViewController: ((_ viewController: UIViewController, _ animated: Bool) -> Void)? { get set }
  
  func viewDidLoad()
  func didTapWalletButton()
}

protocol WalletContainerViewModelChildModuleProvider {
  func getWalletBalanceModuleView(wallet: Wallet) -> UIViewController
}

final class WalletContainerViewModelImplementation: WalletContainerViewModel, WalletContainerModuleOutput {
  
  // MARK: - WalletContainerModuleOutput
  
  var walletButtonHandler: (() -> Void)?
  var didTapSettingsButton: (() -> Void)?
  
  // MARK: - WalletContainerViewModel
  
  var didUpdateModel: ((WalletContainerView.Model) -> Void)?
  var didUpdateWalletBalanceViewController: ((_ viewController: UIViewController, _ animated: Bool) -> Void)?
  
  func viewDidLoad() {
    Task {
      await walletMainController.start(didUpdateActiveWallet: { _ in
        
      }, didUpdateWalletMetaData: { [weak self] wallet in
        self?.didUpdateActiveWalletMetaData(wallet: wallet)
      })
    }
  }
  
  func didTapWalletButton() {
    walletButtonHandler?()
  }

  // MARK: - Dependencies
  
  private let walletBalanceModuleInput: WalletBalanceModuleInput
  private let walletMainController: WalletMainController
  
  init(walletBalanceModuleInput: WalletBalanceModuleInput,
       walletMainController: WalletMainController) {
    self.walletBalanceModuleInput = walletBalanceModuleInput
    self.walletMainController = walletMainController
  }
}

private extension WalletContainerViewModelImplementation {
  func didUpdateActiveWalletMetaData(wallet: Wallet) {
    Task { @MainActor in
      didUpdateModel?(createModel(wallet: wallet))
    }
  }
  
  func createModel(wallet: Wallet) -> WalletContainerView.Model {
    let icon: WalletContainerWalletButton.Model.Icon
    switch wallet.icon {
    case .emoji(let emoji):
      icon = .emoji(emoji)
    case .icon(let image):
      icon = .image(image.image)
    }
    
    let walletButtonConfiguration = WalletContainerWalletButton.Model(
      title: wallet.label,
      icon: icon,
      color: wallet.tintColor.uiColor
    )

    var settingsButtonConfiguration = TKButton.Configuration.accentButtonConfiguration(
      padding: UIEdgeInsets(
        top: 10,
        left: 10,
        bottom: 10,
        right: 10
      )
    )
    settingsButtonConfiguration.content.icon = .TKUIKit.Icons.Size28.gearOutline
    settingsButtonConfiguration.iconTintColor = .Icon.secondary
    settingsButtonConfiguration.action = { [weak self] in
      self?.didTapSettingsButton?()
    }

    let topBarViewModel = WalletContainerTopBarView.Model(
      walletButtonConfiguration: walletButtonConfiguration,
      settingButtonConfiguration: settingsButtonConfiguration
    )
    return WalletContainerView.Model(
      topBarViewModel: topBarViewModel
    )
  }
}
