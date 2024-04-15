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
    Task {
      await walletMainController.start(didUpdateActiveWallet: { [weak self] wallet in
        self?.didUpdateActiveWallet(wallet: wallet)
      }, didUpdateWalletMetaData: { [weak self] walletModel in
        self?.didUpdateActiveWalletMetaData(walletModel: walletModel)
      })
    }
//    walletMainController.didUpdateActiveWallet = { [weak self] in
//      guard let self = self else { return }
//      Task { @MainActor in
//        self.didUpdateActiveWallet()
//      }
//    }
//    walletMainController.didUpdateActiveWalletMetaData = { [weak self] in
//      guard let self = self else { return }
//      Task { @MainActor in
//        self.didUpdateActiveWalletMetaData()
//      }
//    }
//    
//    didUpdateActiveWallet()
//    Task {
//      await walletMainController.start()
//    }
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
  func didUpdateActiveWallet(wallet: Wallet) {
    Task { @MainActor in
      setupWalletBalance(wallet: wallet, animated: true)
    }
  }
  
  func didUpdateActiveWalletMetaData(walletModel: WalletModel) {
    Task { @MainActor in
      didUpdateModel?(createModel(walletModel: walletModel))
    }
  }
  
  func createModel(walletModel: WalletModel) -> WalletContainerView.Model {
    let walletButtonConfiguration = TKButton.Configuration(
      content: TKButton.Configuration.Content(title: .plainString(walletModel.emojiLabel),
                                              icon: .TKUIKit.Icons.Size16.chevronDown),
      contentPadding: UIEdgeInsets(top: 10, left: 12, bottom: 10, right: 12),
      padding: .zero,
      spacing: 6,
      textStyle: .label2,
      textColor: .Button.primaryForeground,
      iconPosition: .right,
      iconTintColor: .Button.primaryForeground,
      backgroundColors: [.normal: walletModel.tintColor.uiColor,
                         .highlighted: walletModel.tintColor.uiColor.withAlphaComponent(0.88)],
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
  
  func setupWalletBalance(wallet: Wallet, animated: Bool) {
    let viewController = childModuleProvider.getWalletBalanceModuleView(wallet: wallet)
    didUpdateWalletBalanceViewController?(viewController, animated)
  }
}
