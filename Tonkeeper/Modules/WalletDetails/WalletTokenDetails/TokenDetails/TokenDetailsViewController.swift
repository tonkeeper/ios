//
//  TokenDetailsTokenDetailsViewController.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 13/07/2023.
//

import UIKit

class TokenDetailsViewController: GenericViewController<TokenDetailsView> {

  // MARK: - Module

  private let presenter: TokenDetailsPresenterInput

  // MARK: - Init

  init(presenter: TokenDetailsPresenterInput) {
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
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    navigationController?.setNavigationBarHidden(false, animated: true)
  }
  
  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    navigationController?.setNavigationBarHidden(true, animated: true)
  }
}

// MARK: - TokenDetailsViewInput

extension TokenDetailsViewController: TokenDetailsViewInput {}

// MARK: - Private

private extension TokenDetailsViewController {
  func setup() {
    view.backgroundColor = .Background.page
  }
}
