//
//  TokensListTokensListViewController.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 26/05/2023.
//

import UIKit

class TokensListViewController: GenericViewController<TokensListView> {

  // MARK: - Module

  private let presenter: TokensListPresenterInput
  
  // MARK: - Collection
  
  private lazy var collectionController = TokensListCollectionController(collectionView: customView.collectionView)

  // MARK: - Init

  init(presenter: TokensListPresenterInput) {
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

// MARK: - TokensListViewInput

extension TokensListViewController: TokensListViewInput {}

// MARK: - Private

private extension TokensListViewController {
  func setup() {}
}
