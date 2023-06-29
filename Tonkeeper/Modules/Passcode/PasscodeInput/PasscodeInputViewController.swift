//
//  PasscodeInputPasscodeInputViewController.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 29/06/2023.
//

import UIKit

class PasscodeInputViewController: GenericViewController<PasscodeInputView> {

  // MARK: - Module

  private let presenter: PasscodeInputPresenterInput

  // MARK: - Init

  init(presenter: PasscodeInputPresenterInput) {
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

// MARK: - PasscodeInputViewInput

extension PasscodeInputViewController: PasscodeInputViewInput {}

// MARK: - Private

private extension PasscodeInputViewController {
  func setup() {
    setupBackButton()
  }
}
