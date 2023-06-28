//
//  SetupWalletSetupWalletPresenter.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 28/06/2023.
//

import Foundation

final class SetupWalletPresenter {
  
  // MARK: - Module
  
  weak var viewInput: SetupWalletViewInput?
  weak var output: SetupWalletModuleOutput?
}

// MARK: - SetupWalletPresenterIntput

extension SetupWalletPresenter: SetupWalletPresenterInput {
  func viewDidLoad() {
    updateWithConfiguration()
  }
}

// MARK: - SetupWalletModuleInput

extension SetupWalletPresenter: SetupWalletModuleInput {}

// MARK: - Private

private extension SetupWalletPresenter {
  func updateWithConfiguration() {
    let createButtons: [ModalContentViewController.Configuration.ActionBar.Button] = [
      .init(title: .createButtonTitle,
            configuration: .primaryLarge),
    ]
    
    let importButtons: [ModalContentViewController.Configuration.ActionBar.Button] = [
      .init(title: .importButtonTitle,
            configuration: .secondaryLarge),
    ]
    
    let actionBarItems: [ModalContentViewController.Configuration.ActionBar.Item] = [
      .buttons(createButtons),
      .buttons(importButtons)
    ]
    
    let configuration = ModalContentViewController.Configuration(
      header: .init(image: .image(image: .Icons.tonIcon128, tintColor: .Accent.blue, backgroundColor: .clear),
                    title: "Let’s set up your wallet",
                    bottomDescription: .description),
      listItems: [],
      actionBar: .init(items: actionBarItems)
    )
    
    viewInput?.update(with: configuration)
  }
}

private extension String {
  static let createButtonTitle = "Create new wallet"
  static let importButtonTitle = "Import existing wallet"
  static let description = """
  You need a connected wallet to use
  Tonkeeper. Either create a new wallet
  or import an existing one.
  """
}
