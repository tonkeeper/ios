//
//  WalletRootViewController.swift
//  Tonkeeper
//
//  Created by Grigory on 23.5.23..
//

import UIKit

final class WalletRootViewController: GenericViewController<WalletRootView> {
  
  // MARK: - Module
  
  private let presenter: WalletRootPresenterInput
  
  // MARK: - Init
  
  init(presenter: WalletRootPresenterInput) {
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
  }
}

// MARK: - WalletRootViewInput

extension WalletRootViewController: WalletRootViewInput {
  
}

// MARK: - Private

private extension WalletRootViewController {
  func setup() {
      title = "Wallet"
  }
}
