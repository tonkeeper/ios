//
//  SettingsRecoveryPhrasePresenter.swift
//  Tonkeeper
//
//  Created by Grigory on 11.10.23..
//

import Foundation
import WalletCoreKeeper
import WalletCoreCore
import UIKit

final class SettingsRecoveryPhrasePresenter {
  
  // MARK: - Module
  
  weak var viewInput: SettingsRecoveryPhraseViewInput?
  weak var output: SettingsRecoveryPhraseModuleOutput?
  
  // MARK: - Dependencies
  
  private let walletProvider: WalletProvider
  private let isBackup: Bool
  
  // MARK: - Init
  
  init(walletProvider: WalletProvider,
       isBackup: Bool) {
    self.walletProvider = walletProvider
    self.isBackup = isBackup
  }
}

// MARK: - SettingsRecoveryPhrasePresenterIntput

extension SettingsRecoveryPhrasePresenter: SettingsRecoveryPhrasePresenterInput {
  func viewDidLoad() {
    updateView()
  }
}

// MARK: - SettingsRecoveryPhraseModuleInput

extension SettingsRecoveryPhrasePresenter: SettingsRecoveryPhraseModuleInput {}

// MARK: - Private

private extension SettingsRecoveryPhrasePresenter {
  func updateView() {
    let title = String.title
      .attributed(with: .h2, alignment: .center, color: .Text.primary)
    let description = String.description
      .attributed(with: .body1, alignment: .center, color: .Text.secondary)
    
    var wordViewModels = [RecoveryPhraseWordView.Model]()
    do {
      let wallet = try walletProvider.activeWallet
      let mnemonic = try walletProvider.getWalletMnemonic(wallet)
      wordViewModels = mnemonic
        .mnemonicWords
        .enumerated()
        .map {
          .init(orderNumber: $0.offset + 1, word: $0.element)
        }
    } catch {}
    
    let buttonConfiguration: TKButton.Configuration = isBackup ? .primaryLarge : .secondaryLarge
    let buttonModel = TKButton.Model(
      title: .string(isBackup ? "Check Backup" : "Copy")
    )
    
    let model = SettingsRecoveryPhraseView.Model(
      scrollContainerModel: .init(
        title: title,
        description: description), phraseListViewModel: .init(wordModels: wordViewModels),
      buttonConfiguration: buttonConfiguration,
      buttonModel: buttonModel) { [weak self] in
        guard let self = self else { return }
        if isBackup {
          self.output?.settingsRecoveryPhraseModuleCheckBackup()
        } else {
          do {
            let wallet = try self.walletProvider.activeWallet
            let mnemonic = try self.walletProvider.getWalletMnemonic(wallet)
            let string = mnemonic.mnemonicWords.joined(separator: "\n")
            UIPasteboard.general.string = string
            ToastController.showToast(configuration: .copied)
          } catch {}
        }
      }
    viewInput?.update(with: model)
  }
}

private extension String {
  static let title = "Your recovery phrase"
  static let description = "Write down these words with their numbers and store them in a safe place."
}
