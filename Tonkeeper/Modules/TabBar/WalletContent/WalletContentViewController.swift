//
//  WalletContentWalletContentViewController.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 29/05/2023.
//

import UIKit

class WalletContentViewController: GenericViewController<WalletContentView> {

  // MARK: - Module

  private let presenter: WalletContentPresenterInput

  // MARK: - Init

  init(presenter: WalletContentPresenterInput) {
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

// MARK: - WalletContentViewInput

extension WalletContentViewController: WalletContentViewInput {}

// MARK: - Private

private extension WalletContentViewController {
  func setup() {}
}
