//
//  SettingsRecoveryPhraseViewController.swift
//  Tonkeeper
//
//  Created by Grigory on 11.10.23..
//

import UIKit

class SettingsRecoveryPhraseViewController: GenericViewController<SettingsRecoveryPhraseView> {

  // MARK: - Module

  private let presenter: SettingsRecoveryPhrasePresenterInput
  
  // MARK: - Init

  init(presenter: SettingsRecoveryPhrasePresenterInput) {
    self.presenter = presenter
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  // MARK: - View Life cycle

  override func viewDidLoad() {
    super.viewDidLoad()
    setup()
    presenter.viewDidLoad()
  }
}

// MARK: - SettingsListViewInput

extension SettingsRecoveryPhraseViewController: SettingsRecoveryPhraseViewInput {
  func update(with model: SettingsRecoveryPhraseView.Model) {
    customView.configure(model: model)
  }
}

// MARK: - Private

private extension SettingsRecoveryPhraseViewController {
  func setup() {}
}

