//
//  SettingsListSettingsListProtocols.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 25/09/2023.
//

import Foundation

protocol SettingsListModuleOutput: AnyObject {}

protocol SettingsListModuleInput: AnyObject {}

protocol SettingsListPresenterInput {
  func viewDidLoad()
}

protocol SettingsListViewInput: AnyObject {
  func didUpdateSettings(_ sections: [SettingsListSection])
}
