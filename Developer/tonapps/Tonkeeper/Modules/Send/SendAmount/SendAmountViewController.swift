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
  
  private let titleView = SendAmountTitleView()

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

extension SendAmountViewController: SendAmountViewInput {
  func updateTitleView(model: SendAmountTitleView.Model) {
    titleView.configure(model: model)
  }
}

// MARK: - Private

private extension SendAmountViewController {
  func setup() {
    navigationItem.titleView = titleView
  
    setupCloseButton { [weak self] in
      self?.presenter.didTapCloseButton()
    }
  }
}
