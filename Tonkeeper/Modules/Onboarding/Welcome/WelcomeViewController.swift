//
//  WelcomeWelcomeViewController.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 28/06/2023.
//

import UIKit

class WelcomeViewController: GenericViewController<WelcomeView> {

  // MARK: - Module

  private let presenter: WelcomePresenterInput

  // MARK: - Init

  init(presenter: WelcomePresenterInput) {
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

// MARK: - WelcomeViewInput

extension WelcomeViewController: WelcomeViewInput {
  func update(with model: WelcomeView.Model) {
    customView.configure(model: model)
  }
}

// MARK: - Private

private extension WelcomeViewController {
  func setup() {
    customView.button.addTarget(self,
                                action: #selector(didTapButton),
                                for: .touchUpInside)
  }
  
  @objc
  func didTapButton() {
    presenter.didTapContinueButton()
  }
}
