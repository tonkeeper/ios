//
//  SettingsListSettingsListPresenter.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 25/09/2023.
//

import Foundation
import WalletCore
import UIKit

final class SettingsListPresenter {
  
  // MARK: - Module
  
  weak var viewInput: SettingsListViewInput?
  weak var output: SettingsListModuleOutput?
  
  // MARK: - Dependencies
  
  private let settingsController: SettingsController
  private let logoutController: LogoutController
  
  // MARK: - Mapper
  
  private let mapper = SettingsListItemMapper()
  
  // MARK: - Init
  
  init(settingsController: SettingsController,
       logoutController: LogoutController) {
    self.settingsController = settingsController
    self.logoutController = logoutController
    settingsController.addObserver(self)
  }
}

// MARK: - SettingsListPresenterIntput

extension SettingsListPresenter: SettingsListPresenterInput {
  var isTitleLarge: Bool { true }
  var title: String { "Settings" }
  
  func viewDidLoad() {
    updateSettings()
  }
}

// MARK: - SettingsListModuleInput

extension SettingsListPresenter: SettingsListModuleInput {}

extension SettingsListPresenter: SettingsControllerObserver {
  func didUpdateSettings() {
    updateSettings()
  }
}

// MARK: - Private

private extension SettingsListPresenter {
  func updateSettings() {
    let sections = getSettingsItems()
    let models = mapper.mapSettingsSections(sections)
    
    viewInput?.didUpdateSettings(models)
  }
  
  func getSettingsItems() -> [SettingsListSection] {
    [
      SettingsListSection(items: [
        getSecurityItem()
      ]),
      SettingsListSection(items: [
        getCurrencyItem()
      ]),
      SettingsListSection(items: [
        getLogoutItem()
      ])
    ]
  }
  
  func getSecurityItem() -> SettingsListItem {
    SettingsListItem(
      title: "Security",
      option: SettingsListItemOption.plain(SettingsListItemPlainOption(
        accessory: .icon(.init(image: .Icons.SettingsList.security, tintColor: .Accent.blue)),
        handler: { [weak self] in
          guard let self = self else { return }
          output?.settingsListDidSelectSecuritySetting(self)
        }))
    )
  }
  
  func getCurrencyItem() -> SettingsListItem {
    let value = (try? settingsController.getSelectedCurrency().code) ?? ""
    return SettingsListItem(
      title: "Currency",
      option: SettingsListItemOption.plain(SettingsListItemPlainOption(
        accessory: .value(value),
        handler: { [weak self] in
          guard let self = self else { return }
          self.output?.settingsListDidSelectCurrencySetting(self)
        }))
    )
  }
  
  func getLogoutItem() -> SettingsListItem {
    SettingsListItem(
      title: "Log out",
      option: SettingsListItemOption.plain(SettingsListItemPlainOption(
        accessory: .icon(.init(image: .Icons.SettingsList.logout, tintColor: .Accent.blue)),
        handler: { [weak self] in
          guard let self = self else { return }
          
          let actions = [
            UIAlertAction(title: .logoutCancelButtonTitle, style: .cancel),
            UIAlertAction(title: .logoutLogoutButtonTitle, style: .destructive, handler: { _ in
              self.logoutController.logout()
              self.output?.settingsListDidLogout(self)
            })
          ]
          
          self.viewInput?.showAlert(
            title: .logoutTitle,
            description: .logoutDescription,
            actions: actions
          )
        }))
    )
  }
}

private extension String {
  static let logoutTitle = "Log out?"
  static let logoutDescription = "This will erase keys to the wallet. Make sure you have backed up your secret recovery phrase."
  static let logoutCancelButtonTitle = "Cancel"
  static let logoutLogoutButtonTitle = "Log out"
}
