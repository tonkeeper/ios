//
//  SettingsListSettingsListPresenter.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 25/09/2023.
//

import Foundation

final class SettingsListPresenter {
  
  // MARK: - Module
  
  weak var viewInput: SettingsListViewInput?
  weak var output: SettingsListModuleOutput?
}

// MARK: - SettingsListPresenterIntput

extension SettingsListPresenter: SettingsListPresenterInput {
  func viewDidLoad() {
    let sections: [SettingsListSection] = [
      .init(items: [
        .init(title: "Currency", option: .plain(.init(accessory: .value("USD"), handler: {
          print("Pressed currency")
        }))),
      ]),
      .init(items: [
        .init(title: "Log out", option: .plain(.init(accessory: .image(.Icons.tonIcon28), handler: {
          print("Pressed logout")
        })))
      ])
    ]
    viewInput?.didUpdateSettings(sections)
  }
}

// MARK: - SettingsListModuleInput

extension SettingsListPresenter: SettingsListModuleInput {}

// MARK: - Private

private extension SettingsListPresenter {}
