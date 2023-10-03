//
//  SettingsListItemMapper.swift
//  Tonkeeper
//
//  Created by Grigory on 3.10.23..
//

import Foundation

struct SettingsListItemMapper {
  func mapSettingsSections(_ sections: [SettingsListSection]) -> [[SettingsListCellContentView.Model]] {
    let models = sections.map { section in
      section.items.map { item in
        let accessoryModel: SettingsListCellAccessoryView.Model?
        let handler: (() -> Void)?
        
        switch item.option {
        case .plain(let settingsListItemPlainOption):
          switch settingsListItemPlainOption.accessory {
          case .none:
            accessoryModel = nil
          case .value(let value):
            accessoryModel = .text(SettingsListCellTextAccessoryView.Model(text: value))
          case .icon(let icon):
            accessoryModel = .icon(SettingsListCellIconAccessoryView.Model(image: icon.image, tintColor: icon.tintColor))
          case .chevron:
            accessoryModel = .icon(SettingsListCellIconAccessoryView.Model(image: .Icons.SettingsList.chevron, tintColor: .Icon.tertiary))
          case .checkmark:
            accessoryModel = .icon(SettingsListCellIconAccessoryView.Model(image: .Icons.SettingsList.checkmark, tintColor: .Accent.blue))
          }
          handler = settingsListItemPlainOption.handler
        case .switchOption(let settingsListItemSwitchOption):
          accessoryModel = .switchControl(
            SettingsListCellSwitchAccessoryView.Model(
              isOn: settingsListItemSwitchOption.isOn,
              handler: settingsListItemSwitchOption.handler)
          )
          handler = nil
        }

        return SettingsListCellContentView.Model(
          title: item.title,
          accessoryModel: accessoryModel,
          handler: handler
        )
      }
    }
    
    return models
  }
}
