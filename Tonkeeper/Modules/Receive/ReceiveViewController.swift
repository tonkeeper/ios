//
//  ReceiveReceiveViewController.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 05/06/2023.
//

import UIKit

class ReceiveViewController: GenericViewController<ReceiveView> {

  // MARK: - Module

  private let presenter: ReceivePresenterInput

  // MARK: - Init

  init(presenter: ReceivePresenterInput) {
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

// MARK: - ReceiveViewInput

extension ReceiveViewController: ReceiveViewInput {}

// MARK: - Private

private extension ReceiveViewController {
  func setup() {}
}
