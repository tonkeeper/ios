//
//  EnterMnemonicEnterMnemonicPresenter.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 28/06/2023.
//

import Foundation
import WalletCoreKeeper
import WalletCoreCore

final class BackupCheckPresenter {
  
  // MARK: - Module
  
  weak var viewInput: BackupCheckViewInput?
  weak var output: BackupCheckModuleOutput?
  
  private let walletProvider: WalletProvider
  
  let indexes = Array(0..<24).shuffled().prefix(3).sorted()
  lazy var words: [String] = {
    do {
      let wallet = try walletProvider.activeWallet
      let mnemonic = try walletProvider.getWalletMnemonic(wallet).mnemonicWords
      return [mnemonic[indexes[0]], mnemonic[indexes[1]], mnemonic[indexes[2]]]
    } catch {
      return []
    }
  }()
  
  init(walletProvider: WalletProvider) {
    self.walletProvider = walletProvider
  }
}

// MARK: - EnterMnemonicPresenterIntput

extension BackupCheckPresenter: BackupCheckPresenterInput {
  func viewDidLoad() {
    updateView()
  }
  
  func validate(word: String, index: Int) -> Bool {
    do {
      let wallet = try walletProvider.activeWallet
      let mnemonic = try walletProvider.getWalletMnemonic(wallet)
      return mnemonic.mnemonicWords[index - 1] == word
    } catch {
      return false
    }
  }
  
  func didEnterMnemonic(_ mnemonic: [String]) {
    if mnemonic == words {
      output?.didCheckBackup()
    }
  }
}

// MARK: - EnterMnemonicModuleInput

extension BackupCheckPresenter: BackupCheckModuleInput {}

// MARK: - Private

private extension BackupCheckPresenter {
  func updateView() {
    let inputs = indexes.map { BackupCheckView.Model.Input(index: $0 + 1) }
    
    let description = "Let's see if you've got everything right. Enter words \(indexes[0] + 1), \(indexes[1] + 1), and \(indexes[2] + 1)."
    
    let titleString = String.title
      .attributed(with: .h2, alignment: .center, color: .Text.primary)
    let descriptionString = description
      .attributed(with: .body1, alignment: .center, color: .Text.secondary)
    
    let model = BackupCheckView.Model(
      scrollContainerModel: .init(
        title: titleString,
        description: descriptionString),
      continueButtonTitle: .continueButtonTitle,
    inputs: inputs)
    viewInput?.update(with: model)
  }
}

private extension String {
  static let title = "Backup Check"
  static let continueButtonTitle = "Done"
}
