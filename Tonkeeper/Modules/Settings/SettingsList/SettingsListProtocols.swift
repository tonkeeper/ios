//
//  SettingsListSettingsListProtocols.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 25/09/2023.
//

import Foundation

protocol SettingsListModuleOutput: AnyObject {
  func settingsListDidSelectCurrencySetting(_ settingsList: SettingsListModuleInput)
}

protocol SettingsListModuleInput: AnyObject {}

protocol SettingsListPresenterInput {
  var isTitleLarge: Bool { get }
  var title: String { get }
  func viewDidLoad()
}

protocol SettingsListViewInput: AnyObject {
  func didUpdateSettings(_ sections: [[SettingsListCellContentView.Model]])
}
