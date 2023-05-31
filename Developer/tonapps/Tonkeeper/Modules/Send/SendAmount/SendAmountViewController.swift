//
//  SendAmountSendAmountViewController.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 31/05/2023.
//

import UIKit

class SendAmountViewController: GenericViewController<SendAmountView> {

  // MARK: - Module

  private let presenter: SendAmountPresenterInput

  // MARK: - Init

  init(presenter: SendAmountPresenterInput) {
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

// MARK: - SendAmountViewInput

extension SendAmountViewController: SendAmountViewInput {}

// MARK: - Private

private extension SendAmountViewController {
  func setup() {
    title = "Amount"
  }
}
