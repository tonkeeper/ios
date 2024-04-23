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
      await walletMainController.start(didUpdateActiveWallet: { _ in
        
      }, didUpdateWalletMetaData: { [weak self] walletModel in
        self?.didUpdateActiveWalletMetaData(walletModel: walletModel)
      })
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
}
