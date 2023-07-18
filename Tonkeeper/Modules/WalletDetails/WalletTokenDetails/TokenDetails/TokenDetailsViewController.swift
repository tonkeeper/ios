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
  
  // MARK: - Dependencies
  
  private let imageLoader: ImageLoader

  // MARK: - Init

  init(presenter: TokenDetailsPresenterInput,
       imageLoader: ImageLoader) {
    self.presenter = presenter
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
  
  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    navigationController?.setNavigationBarHidden(true, animated: true)
  }
}

// MARK: - TokenDetailsViewInput

extension TokenDetailsViewController: TokenDetailsViewInput {
  func updateTitle(title: String) {
    self.title = title
  }
  func updateHeader(model: TokenDetailsHeaderView.Model) {
    customView.headerView.configure(model: model)
  }
  
  func stopRefresh() {
    customView.refreshControl.endRefreshing()
  }
}

// MARK: - Private

private extension TokenDetailsViewController {
  func setup() {
    view.backgroundColor = .Background.page
    
    customView.headerView.imageLoader = imageLoader
    
    customView.refreshControl.addTarget(self,
                                        action: #selector(didPullToRefresh),
                                        for: .valueChanged)
  }
  
  @objc
  func didPullToRefresh() {
    presenter.didPullToRefresh()
  }
}
