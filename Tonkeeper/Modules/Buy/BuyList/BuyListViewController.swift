//
//  BuyListBuyListViewController.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 09/06/2023.
//

import UIKit

class BuyListViewController: GenericViewController<BuyListView>, ModalCardContainerContent {
  
  // MARK: - Module

  private let presenter: BuyListPresenterInput

  // MARK: - Init

  init(presenter: BuyListPresenterInput) {
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
  
  // MARK: - ModalCardContainerContent
  
  var height: CGFloat { return 200 }
  
  var didUpdateHeight: (() -> Void)?
}

// MARK: - BuyListViewInput

extension BuyListViewController: BuyListViewInput {}

// MARK: - Private

private extension BuyListViewController {
  func setup() {}
}
