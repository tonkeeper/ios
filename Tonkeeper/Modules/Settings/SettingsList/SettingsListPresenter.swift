//
//  SettingsListSettingsListPresenter.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 25/09/2023.
//

import Foundation
import WalletCore
import UIKit
import TKCore

final class SettingsListPresenter {
  
  // MARK: - Module
  
  weak var viewInput: SettingsListViewInput?
  weak var output: SettingsListModuleOutput?
  
  // MARK: - Dependencies
  
  private let settingsController: SettingsController
  private let logoutController: LogoutController
  private let urlOpener: URLOpener
  private let infoProvider: InfoProvider
  private let appStoreReviewer: AppStoreReviewer
  
  // MARK: - Mapper
  
  private let mapper = SettingsListItemMapper()
  
  // MARK: - Init
  
  init(settingsController: SettingsController,
       logoutController: LogoutController,
       urlOpener: URLOpener,
       infoProvider: InfoProvider,
       appStoreReviewer: AppStoreReviewer) {
    self.settingsController = settingsController
    self.logoutController = logoutController
    self.urlOpener = urlOpener
    self.infoProvider = infoProvider
    self.appStoreReviewer = appStoreReviewer
    settingsController.addObserver(self)
  }
  
  deinit {
    settingsController.removeObserver(self)
  }
}

// MARK: - SettingsListPresenterIntput

extension SettingsListPresenter: SettingsListPresenterInput {
  var isTitleLarge: Bool { true }
  var title: String { "Settings" }
  
  func viewDidLoad() {
    updateSettings()
    updateFooter()
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
  
  func updateFooter() {
    do {
      let appName: String = try infoProvider.value(for: .appName)
      let appVersion: String = try infoProvider.value(for: .appVersion)
      let buildVersion: String = try infoProvider.value(for: .buildVersion)
      let version = "Version \(appVersion)(\(buildVersion))"
      viewInput?.updateFooter(.init(appName: appName, version: version))
    } catch {}
  }
  
  func getSettingsItems() -> [SettingsListSection] {
    [
      SettingsListSection(items: [
        getSecurityItem()
      ]),
      SettingsListSection(items: [
        getCurrencyItem()
      ]),
      socialLinksSection(),
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
  
  func socialLinksSection() -> SettingsListSection {
    .init(items: [
      supportLinkItem(),
      tonkeeperNewsLinkItem(),
      contactUsLinkItem(),
      rateTonkeeperItem()
    ])
  }
  
  func supportLinkItem() -> SettingsListItem {
    SettingsListItem(
      title: .supportTitle,
      option: .plain(.init(
        accessory: .icon(.init(image: .Icons.SettingsList.support, tintColor: .Accent.blue)),
        handler: { [weak self] in
          guard let self = self else { return }
          guard let urlString: String = try? self.infoProvider.value(for: .supportURL),
          let url = URL(string: urlString)  else { return }
          self.urlOpener.open(url: url)
        })
      )
    )
  }
  
  func tonkeeperNewsLinkItem() -> SettingsListItem {
    SettingsListItem(
      title: .tonkeeperNewsTitle,
      option: .plain(.init(
        accessory: .icon(.init(image: .Icons.SettingsList.tonkeeperNews, tintColor: .Icon.secondary)),
        handler: { [weak self] in
          guard let self = self else { return }
          guard let urlString: String = try? self.infoProvider.value(for: .tonkeeperNewsURL),
          let url = URL(string: urlString)  else { return }
          self.urlOpener.open(url: url)
        })
      )
    )
  }
  
  func contactUsLinkItem() -> SettingsListItem {
    SettingsListItem(
      title: .contactUsTitle,
      option: .plain(.init(
        accessory: .icon(.init(image: .Icons.SettingsList.contactUs, tintColor: .Icon.secondary)),
        handler: { [weak self] in
          guard let self = self else { return }
          guard let urlString: String = try? self.infoProvider.value(for: .contactUsURL),
          let url = URL(string: urlString)  else { return }
          self.urlOpener.open(url: url)
        })
      )
    )
  }
  
  func rateTonkeeperItem() -> SettingsListItem {
    SettingsListItem(
      title: .rateTonkeeperXTitle,
      option: .plain(.init(
        accessory: .icon(.init(image: .Icons.SettingsList.rate, tintColor: .Icon.secondary)),
        handler: { [weak self] in
          self?.appStoreReviewer.requestReview()
        })
      )
    )
  }
  
  func legalItem() -> SettingsListItem {
    SettingsListItem(
      title: .legalTitle,
      option: .plain(.init(
        accessory: .icon(.init(image: .Icons.SettingsList.legal, tintColor: .Icon.secondary)),
        handler: {})
      )
    )
  }
}

private extension String {
  static let logoutTitle = "Log out?"
  static let logoutDescription = "This will erase keys to the wallet. Make sure you have backed up your secret recovery phrase."
  static let logoutCancelButtonTitle = "Cancel"
  static let logoutLogoutButtonTitle = "Log out"
  static let supportTitle = "Support"
  static let tonkeeperNewsTitle = "Tonkeeper news"
  static let contactUsTitle = "Contact us"
  static let rateTonkeeperXTitle = "Rate Tonkeeper X"
  static let legalTitle = "Legal"
}
