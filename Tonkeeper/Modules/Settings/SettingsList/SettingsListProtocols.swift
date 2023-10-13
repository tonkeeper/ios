//
//  SettingsListSettingsListProtocols.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 25/09/2023.
//

import Foundation
import UIKit

protocol SettingsListModuleOutput: AnyObject {
  func settingsListDidSelectSecuritySetting(_ settingsList: SettingsListModuleInput)
  func settingsListDidSelectCurrencySetting(_ settingsList: SettingsListModuleInput)
  func settingsListDidLogout(_ settingsList: SettingsListModuleInput)
}

protocol SettingsListModuleInput: AnyObject {}

protocol SettingsListPresenterInput {
  var isTitleLarge: Bool { get }
  var title: String { get }
  func viewDidLoad()
}

protocol SettingsListViewInput: AnyObject {
  func didUpdateSettings(_ sections: [[SettingsListCellContentView.Model]])
  func updateFooter(_ footerModel: SettingsListFooterView.Model)
  func openKeychainRestore()
  func showAlert(title: String, description: String?, actions: [UIAlertAction])
}
