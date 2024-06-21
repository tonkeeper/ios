import Foundation
import TKUIKit
import UIKit
import KeeperCore

protocol WalletContainerModuleOutput: AnyObject {
  var didTapWalletButton: (() -> Void)? { get set }
  var didTapSettingsButton: (() -> Void)? { get set }
}

protocol WalletContainerViewModel: AnyObject {
  var didUpdateModel: ((WalletContainerView.Model) -> Void)? { get set }
  var didUpdateWalletBalanceViewController: ((_ viewController: UIViewController, _ animated: Bool) -> Void)? { get set }
  
  func viewDidLoad()
}

protocol WalletContainerViewModelChildModuleProvider {
  func getWalletBalanceModuleView(wallet: Wallet) -> UIViewController
}

final class WalletContainerViewModelImplementation: WalletContainerViewModel, WalletContainerModuleOutput {
  
  // MARK: - WalletContainerModuleOutput
  
  var didTapWalletButton: (() -> Void)?
  var didTapSettingsButton: (() -> Void)?
  
  // MARK: - WalletContainerViewModel
  
  var didUpdateModel: ((WalletContainerView.Model) -> Void)?
  var didUpdateWalletBalanceViewController: ((_ viewController: UIViewController, _ animated: Bool) -> Void)?
  
  func viewDidLoad() {
    walletMainController.didUpdateActiveWallet = { [weak self] wallet in
      DispatchQueue.main.async {
        self?.wallet = wallet
      }
    }
    walletMainController.start()
  }
  
  // MARK: - State
  
  private var wallet: Wallet? {
    didSet {
      guard let wallet,
            wallet.metaData != oldValue?.metaData else { return }
      didUpdateModel?(createModel(wallet: wallet))
    }
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
  func createModel(wallet: Wallet) -> WalletContainerView.Model {
    let walletButtonConfiguration = TKButton.Configuration(
      content: TKButton.Configuration.Content(title: .plainString(wallet.emojiLabel),
                                              icon: .TKUIKit.Icons.Size16.chevronDown),
      contentPadding: UIEdgeInsets(top: 10, left: 12, bottom: 10, right: 12),
      padding: .zero,
      spacing: 6,
      textStyle: .label2,
      textColor: .Button.primaryForeground,
      iconPosition: .right,
      iconTintColor: .Button.primaryForeground,
      backgroundColors: [.normal: wallet.tintColor.uiColor,
                         .highlighted: wallet.tintColor.uiColor.withAlphaComponent(0.88)],
      contentAlpha: [.normal: 1],
      cornerRadius: 20) { [weak self] in
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        self?.didTapWalletButton?()
      }
    
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
