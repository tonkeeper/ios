import UIKit
import TKUIKit
import TKCore
import KeeperCore

public protocol SettingsRootModuleOutput: AnyObject {
  
}

protocol SettingsRootViewModel: AnyObject {
  var didUpdateSettingsSections: (([SettingsSection]) -> Void)? { get set }
  var didShowAlert: ((String, String?, [UIAlertAction]) -> Void)? { get set }
  
  func viewDidLoad()
  func selectItem(section: SettingsSection, index: Int)
}

final class SettingsRootViewModelImplementation: SettingsRootViewModel, SettingsRootModuleOutput {
  
  // MARK: - SettingsRootModuleOutput
  
  
  // MARK: - SettingsRootViewModel
  
  var didUpdateSettingsSections: (([SettingsSection]) -> Void)?
  var didShowAlert: ((String, String?, [UIAlertAction]) -> Void)?

  func viewDidLoad() {
    didUpdateSettingsSections?(setupSettingsSections())
  }
  
  func selectItem(section: SettingsSection, index: Int) {
    switch section {
//    case .wallet(let item):
//      print("select item")
    case .settingsItems(let items):
      (items[index] as? SettingsCell.Model)?.selectionHandler?()
    }
  }
  
//  private let settingsController: SettingsController
//  
//  init(settingsController: SettingsController) {
//    self.settingsController = settingsController
//  }
}

private extension SettingsRootViewModelImplementation {
  func setupSettingsSections() -> [SettingsSection] {
    [
//      setupWalletSection(),
      setupSecuritySection(),
      setupSocialLinksSection(),
      setupLogoutSection()
    ]
  }
  
//  func setupWalletSection() -> SettingsSection {
//    let cellContentModel = WalletsListWalletCellContentView.Model(
//      emoji: "👹",
//      backgroundColor: .blue,
//      walletName: "Wallet hello",
//      balance: "Edit name and color"
//    )
//    
//    let cellModel = WalletsListWalletCell.Model(
//      identifier: "wallet",
//      selectionHandler: {
//        
//      },
//      cellContentModel: cellContentModel
//    )
//    
//    return .wallet(item: cellModel)
//  }
  
  func setupSecuritySection() -> SettingsSection {
    SettingsSection.settingsItems(items: [
      setupSecurityItem(),
      setupBackupItem()
    ])
  }
  
  func setupSecurityItem() -> SettingsCell.Model {
    SettingsCell.Model(
      identifier: .securityItemTitle,
      selectionHandler: {
        print("Log out")
      },
      cellContentModel: SettingsCellContentView.Model(
        title: .securityItemTitle,
        icon: .TKUIKit.Icons.Size28.key,
        tintColor: .Accent.blue
      )
    )
  }
  
  func setupBackupItem() -> SettingsCell.Model {
    SettingsCell.Model(
      identifier: .backupItemTitle,
      selectionHandler: {
        print("Log out")
      },
      cellContentModel: SettingsCellContentView.Model(
        title: .backupItemTitle,
        icon: .TKUIKit.Icons.Size28.lock,
        tintColor: .Accent.blue
      )
    )
  }
  
  func setupSocialLinksSection() -> SettingsSection {
    SettingsSection.settingsItems(items: [
      setupSupportItem(),
      setupTonkeeperNewsItem(),
      setupContactUsItem(),
      setupRateItem(),
      setupDeleteAccountItem()
    ])
  }
  
  func setupSupportItem() -> SettingsCell.Model {
    SettingsCell.Model(
      identifier: .logoutItemTitle,
      selectionHandler: {
        print("Log out")
      },
      cellContentModel: SettingsCellContentView.Model(
        title: .supportTitle,
        icon: .TKUIKit.Icons.Size28.telegram,
        tintColor: .Accent.blue
      )
    )
  }
  
  func setupTonkeeperNewsItem() -> SettingsCell.Model {
    SettingsCell.Model(
      identifier: .tonkeeperNewsTitle,
      selectionHandler: {
        print("Log out")
      },
      cellContentModel: SettingsCellContentView.Model(
        title: .tonkeeperNewsTitle,
        icon: .TKUIKit.Icons.Size28.telegram,
        tintColor: .Icon.secondary
      )
    )
  }
  
  func setupContactUsItem() -> SettingsCell.Model {
    SettingsCell.Model(
      identifier: .contactUsTitle,
      selectionHandler: {
        print("Log out")
      },
      cellContentModel: SettingsCellContentView.Model(
        title: .contactUsTitle,
        icon: .TKUIKit.Icons.Size28.messageBubble,
        tintColor: .Icon.secondary
      )
    )
  }
  
  func setupRateItem() -> SettingsCell.Model {
    SettingsCell.Model(
      identifier: .rateTonkeeperXTitle,
      selectionHandler: {
        print("Log out")
      },
      cellContentModel: SettingsCellContentView.Model(
        title: .rateTonkeeperXTitle,
        icon: .TKUIKit.Icons.Size28.star,
        tintColor: .Icon.secondary
      )
    )
  }
  
  func setupDeleteAccountItem() -> SettingsCell.Model {
    SettingsCell.Model(
      identifier: .deleteItemTitle,
      selectionHandler: { [weak self] in
        guard let self = self else { return }
        
        let actions = [
          UIAlertAction(title: .deleteDeleteButtonTitle, style: .destructive, handler: { _ in
          }),
          UIAlertAction(title: .deleteCancelButtonTitle, style: .cancel)
        ]
        
        self.didShowAlert?(.deleteTitle, .deleteDescription, actions)
      },
      cellContentModel: SettingsCellContentView.Model(
        title: .deleteItemTitle,
        icon: .TKUIKit.Icons.Size28.trashBin,
        tintColor: .Icon.secondary
      )
    )
  }
  
  func setupLogoutSection() -> SettingsSection {
    SettingsSection.settingsItems(items: [
      setupLogoutItem()
    ])
  }
  
  func setupLogoutItem() -> SettingsCell.Model {
    SettingsCell.Model(
      identifier: .logoutItemTitle,
      selectionHandler: {
        print("Log out")
      },
      cellContentModel: SettingsCellContentView.Model(
        title: .logoutItemTitle,
        icon: .TKUIKit.Icons.Size28.door,
        tintColor: .Accent.blue
      )
    )
  }
}

private extension String {
  static let securityItemTitle = "Security"
  
  static let backupItemTitle = "Backup"
  
  static let logoutItemTitle = "Sign Out"
  static let logoutTitle = "Log out?"
  static let logoutDescription = "This will erase keys to the wallet. Make sure you have backed up your secret recovery phrase."
  static let logoutCancelButtonTitle = "Cancel"
  static let logoutLogoutButtonTitle = "Log out"
  
  static let supportTitle = "Support"
  static let tonkeeperNewsTitle = "Tonkeeper news"
  static let contactUsTitle = "Contact us"
  static let rateTonkeeperXTitle = "Rate Tonkeeper X"
  static let legalTitle = "Legal"
  
  static let deleteItemTitle = "Delete account"
  static let deleteTitle = "Are you sure you want to delete your account?"
  static let deleteDescription = "This action will delete your account and all data from this application."
  static let deleteDeleteButtonTitle = "Delete account and data"
  static let deleteCancelButtonTitle = "Cancel"
}
