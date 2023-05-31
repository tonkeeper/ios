//
//  WalletHeaderViewController.swift
//  Tonkeeper
//
//  Created by Grigory on 25.5.23..
//

import UIKit

final class WalletHeaderViewController: GenericViewController<WalletHeaderView> {
  
  // MARK: - Module
  
  private let presenter: WalletHeaderPresenterInput
  
  // MARK: - Init
  
  init(presenter: WalletHeaderPresenterInput) {
    self.presenter = presenter
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  // MARK: - View Life Cycle
  
  override func viewDidLoad() {
    super.viewDidLoad()
    setup()
    presenter.viewDidLoad()
  }
}

// MARK: - WalletHeaderViewInput

extension WalletHeaderViewController: WalletHeaderViewInput {
  func update(with model: WalletHeaderView.Model) {
    customView.configure(model: model)
  }
  
  func updateButtons(with models: [WalletHeaderButtonModel]) {
    let buttons: [IconButton] = models.map { model in
      let iconButton = IconButton()
      iconButton.configure(model: model.viewModel)
      iconButton.addAction(.init(handler: {
        model.handler?()
      }), for: .touchUpInside)
      return iconButton
    }
    customView.buttonsView.buttons = buttons
  }
}

// MARK: - Private

private extension WalletHeaderViewController {
  func setup() {
    customView.addressButton.addTarget(
      self,
      action: #selector(didTapAddressButton),
      for: .touchUpInside
    )
  }
}

// MARK: - Actions

private extension WalletHeaderViewController {
  @objc
  func didTapAddressButton() {
    presenter.didTapAddressButton()
  }
}
