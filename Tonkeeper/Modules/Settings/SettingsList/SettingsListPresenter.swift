//
//  SettingsListSettingsListPresenter.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 25/09/2023.
//

import Foundation
import WalletCore

final class SettingsListPresenter {
  
  // MARK: - Module
  
  weak var viewInput: SettingsListViewInput?
  weak var output: SettingsListModuleOutput?
  
  // MARK: - Dependencies
  
  private let settingsController: SettingsController
  
  // MARK: - Mapper
  
  private let mapper = SettingsListItemMapper()
  
  // MARK: - Init
  
  init(settingsController: SettingsController) {
    self.settingsController = settingsController
  }
}

// MARK: - SettingsListPresenterIntput

extension SettingsListPresenter: SettingsListPresenterInput {
  func viewDidLoad() {
    let sections = getSettingsItems()
    let models = mapper.mapSettingsSections(sections)
    
    viewInput?.didUpdateSettings(models)
  }
}

// MARK: - SettingsListModuleInput

extension SettingsListPresenter: SettingsListModuleInput {}

// MARK: - Private

private extension SettingsListPresenter {
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
      ]),
    ]
  }
  
  func getSecurityItem() -> SettingsListItem {
    SettingsListItem(
      title: "Security",
      option: SettingsListItemOption.plain(SettingsListItemPlainOption(
        accessory: .icon(.init(image: .Icons.SettingsList.security, tintColor: .Accent.blue)),
        handler: {
          print("Pressed security")
        }))
    )
  }
  
  func getCurrencyItem() -> SettingsListItem {
    SettingsListItem(
      title: "Currency",
      option: SettingsListItemOption.plain(SettingsListItemPlainOption(
        accessory: .value("USD"),
        handler: {
          print("Pressed Currency")
        }))
    )
  }
  
  func getLogoutItem() -> SettingsListItem {
    SettingsListItem(
      title: "Log out",
      option: SettingsListItemOption.plain(SettingsListItemPlainOption(
        accessory: .icon(.init(image: .Icons.SettingsList.logout, tintColor: .Accent.blue)),
        handler: {
          print("Pressed logout")
        }))
    )
  }
}
