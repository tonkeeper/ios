//
//  SettingsSecurityPresenter.swift
//  Tonkeeper
//
//  Created by Grigory on 10.10.23..
//

import Foundation
import WalletCoreKeeper

final class SettingsSecurityPresenter {
  
  // MARK: - Module
  
  weak var viewInput: SettingsListViewInput?
  weak var output: SettingsSecurityModuleOutput?
  
  // MARK: - Mapper
  
  private let mapper = SettingsListItemMapper()
   
  // MARK: - Init
  
  private let biometryAuthentificator: BiometryAuthentificator
  private let settingsController: SettingsController
  
  init(biometryAuthentificator: BiometryAuthentificator,
       settingsController: SettingsController) {
    self.biometryAuthentificator = biometryAuthentificator
    self.settingsController = settingsController
  }
}

// MARK: - SettingsListPresenterIntput

extension SettingsSecurityPresenter: SettingsListPresenterInput {
  var isTitleLarge: Bool { false }
  var title: String { .title }
  
  func viewDidLoad() {
    updateSettings()
  }
}

private extension SettingsSecurityPresenter {
  func updateSettings() {
    
    let sections = [
      SettingsListSection(items: [getFaceIdSetting()]),
      SettingsListSection(items: [getRecoveryPhraseSetting()])
    ]
    let models = mapper.mapSettingsSections(sections)
    viewInput?.didUpdateSettings(models)
  }
  
  func getFaceIdSetting() -> SettingsListItem {
    let isTurnedOn = settingsController.getIsBiometryEnabled()
    
    let option: SettingsListItemOption = {
      let isOn: Bool
      let isEnabled: Bool
      
      let result = biometryAuthentificator.canEvaluate(policy: .deviceOwnerAuthenticationWithBiometrics)
      switch result {
      case .success:
        isOn = isTurnedOn
        isEnabled = true
      case .failure:
        isOn = false
        isEnabled = false
      }
      
      return .switchOption(.init(isOn: isOn, isEnabled: isEnabled, handler: { [weak self] newValue in
        guard let self = self else { return false }
        
        let isConfirmed = await {
          guard newValue else { return true }
          return await self.askActionConfirmation()
        }()
        
        guard isConfirmed else { return isConfirmed }
        
        do {
          try self.settingsController.setIsBiometryEnabled(newValue)
          return isConfirmed
        } catch {
          return false
        }
      }))
    }()
   
    let title: String
    switch biometryAuthentificator.biometryType {
    case .touchID:
      title = .use + " " + .touchId
    case .faceID:
      title = .use + " " + .faceId
    default:
      title = .biometryUnavailable
    }
    let item = SettingsListItem(
      title: title,
      option: option
    )
    
    return item
  }
  
  func getRecoveryPhraseSetting() -> SettingsListItem {
    SettingsListItem(
      title: .showRecoveryPhrase,
      option: .plain(.init(
        accessory: .icon(.init(image: .Icons.SettingsList.security,
                               tintColor: .Accent.blue)),
        handler: { [weak self] in
          guard let self = self else { return }
          Task {
            let isConfirmed = await self.askActionConfirmation()
            guard isConfirmed else { return }
            await MainActor.run {
              self.output?.settingsSecurityDidSelectShowRecoveryPhrase()
            }
          }
        }))
    )
  }
  
  func askActionConfirmation() async -> Bool {
    guard let output = output else { return false }
    return await output.settingsSecurityConfirmation()
  }
}

private extension String {
  static let title = "Security"
  static let use = "Use"
  static let faceId = "Face ID"
  static let touchId = "Touch ID"
  static let biometryUnavailable = "Biometry unavailable"
  static let showRecoveryPhrase = "Show recovery phrase"
}
