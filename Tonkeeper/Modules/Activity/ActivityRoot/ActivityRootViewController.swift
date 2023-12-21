//
//  ActivityRootActivityRootViewController.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 06/06/2023.
//

import UIKit

class ActivityRootViewController: GenericViewController<ActivityRootView>, ScrollViewController {

  // MARK: - Module

  private let presenter: ActivityRootPresenterInput
  
  // MARK: - Children
  
  private let emptyViewController: ActivityEmptyViewController
  private let listViewController: ActivityListViewController

  // MARK: - Init

  init(presenter: ActivityRootPresenterInput,
       emptyViewController: ActivityEmptyViewController,
       listViewController: ActivityListViewController) {
    self.presenter = presenter
    self.emptyViewController = emptyViewController
    self.listViewController = listViewController
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
    customView.showList()
  }
  
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    listViewController.scrollView.contentInset.top = customView.navigationBarView.additionalInset
  }
  
  // MARK: - ScrollViewController
  
  func scrollToTop() {
    listViewController.scrollToTop()
  }
}

// MARK: - ActivityRootViewInput

extension ActivityRootViewController: ActivityRootViewInput {
  func showEmptyState() {
    customView.showEmptyState()
    customView.navigationBarView.scrollView = nil
  }

  func showList() {
    customView.showList()
    customView.navigationBarView.scrollView = listViewController.scrollView
  }
  
  func updateTitle(_ title: String) {
    customView.navigationBarView.title = title
    customView.largeTitleView.title = title
  }
  
  func setIsConnecting(_ isConnecting: Bool) {
    customView.largeTitleView.isLoading = isConnecting
  }
}

// MARK: - Private

private extension ActivityRootViewController {
  func setup() {
    setupEmptyViewController()
    setupListViewController()
  }
  
  func setupEmptyViewController() {
    addChild(emptyViewController)
    customView.addEmptyContentView(view: emptyViewController.view)
    emptyViewController.didMove(toParent: self)
  }
  
  func setupListViewController() {
    addChild(listViewController)
    customView.addListContentView(view: listViewController.view)
    listViewController.didMove(toParent: self)
  }
}
