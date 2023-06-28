//
//  EnterMnemonicEnterMnemonicViewController.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 28/06/2023.
//

import UIKit

class EnterMnemonicViewController: GenericViewController<EnterMnemonicView> {

  // MARK: - Module

  private let presenter: EnterMnemonicPresenterInput

  // MARK: - Init

  init(presenter: EnterMnemonicPresenterInput) {
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

// MARK: - EnterMnemonicViewInput

extension EnterMnemonicViewController: EnterMnemonicViewInput {}

// MARK: - Private

private extension EnterMnemonicViewController {
  func setup() {}
}
