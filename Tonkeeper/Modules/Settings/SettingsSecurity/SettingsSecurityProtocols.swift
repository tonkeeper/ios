//
//  SettingsSecurityProtocols.swift
//  Tonkeeper
//
//  Created by Grigory on 10.10.23..
//

import Foundation

protocol SettingsSecurityModuleOutput: AnyObject {
  func settingsSecurityConfirmation() async -> Bool
  func settingsSecurityDidSelectShowRecoveryPhrase()
}
