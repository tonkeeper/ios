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
  
  func viewDidLoad()
  func didTapWalletButton()
}

final class WalletContainerViewModelImplementation: WalletContainerViewModel, WalletContainerModuleOutput {
  
  // MARK: - WalletContainerModuleOutput
  
  var walletButtonHandler: (() -> Void)?
  var didTapSettingsButton: (() -> Void)?
  
  // MARK: - WalletContainerViewModel
  
  var didUpdateModel: ((WalletContainerView.Model) -> Void)?
  
  func viewDidLoad() {
    walletsStore.addObserver(self, notifyOnAdded: true) { observer, walletsStore, _ in
      DispatchQueue.main.async {
        self.wallet = walletsStore.activeWallet
      }
    }
  }
  
  // MARK: - State
  
  private var wallet: Wallet? {
    didSet {
      guard let wallet,
            wallet.metaData != oldValue?.metaData else { return }
      didUpdateModel?(createModel(wallet: wallet))
    }
  }
  
  func didTapWalletButton() {
    walletButtonHandler?()
  }

  // MARK: - Dependencies
  
  private let walletsStore: WalletsStoreV2
  
  // MARK: - Init
  
  init(walletsStore: WalletsStoreV2) {
    self.walletsStore = walletsStore
  }
}

private extension WalletContainerViewModelImplementation {
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
