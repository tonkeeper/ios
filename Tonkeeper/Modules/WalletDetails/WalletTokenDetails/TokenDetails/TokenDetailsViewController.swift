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
  
  // MARK: - Children
  
  private let listContentViewController: TokenDetailsListContentViewController
  
  // MARK: - Dependencies
  
  private let imageLoader: ImageLoader
  
  // MARK: - Header
  
  private let headerView = TokenDetailsHeaderView()

  // MARK: - Init

  init(presenter: TokenDetailsPresenterInput,
       listContentViewController: TokenDetailsListContentViewController,
       imageLoader: ImageLoader) {
    self.presenter = presenter
    self.listContentViewController = listContentViewController
    self.imageLoader = imageLoader
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
}

// MARK: - TokenDetailsViewInput

extension TokenDetailsViewController: TokenDetailsViewInput {
  func updateTitle(title: String) {
    self.title = title
  }
  
  func updateHeader(model: TokenDetailsHeaderView.Model) {
    headerView.configure(model: model)
  }
  
  func stopRefresh() {
    customView.refreshControl.endRefreshing()
  }
}

// MARK: - Private

private extension TokenDetailsViewController {
  func setup() {
    view.backgroundColor = .Background.page
    
    headerView.imageLoader = imageLoader
    
    setupListContent()
  }
  
  func setupListContent() {
    addChild(listContentViewController)
    customView.embedListView(listContentViewController.view)
    listContentViewController.didMove(toParent: self)
    
    listContentViewController.setHeaderView(headerView)
  }
  
  @objc
  func didPullToRefresh() {
    presenter.didPullToRefresh()
  }
}
