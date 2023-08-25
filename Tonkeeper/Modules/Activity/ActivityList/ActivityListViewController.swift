//
//  ActivityListActivityListViewController.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 06/06/2023.
//

import UIKit

class ActivityListViewController: GenericViewController<ActivityListView> {

  var scrollView: UIScrollView {
    customView.collectionView
  }
  
  var didStartRefresh: (() -> Void)?
  
  private var headerViewController: UIViewController?
  
  // MARK: - Module

  private let presenter: ActivityListPresenterInput
  
  // MARK: - Collection
  
  private lazy var collectionController: ActivityListCollectionController = {
    let controller = ActivityListCollectionController(collectionView: customView.collectionView)
    controller.delegate = self
    return controller
  }()

  // MARK: - Init

  init(presenter: ActivityListPresenterInput) {
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
  
  func setHeaderView(_ headerView: UIView?) {
    collectionController.headerView = headerView
  }
  
  func setHeaderViewController(_ headerViewController: UIViewController?) {
    self.headerViewController?.willMove(toParent: nil)
    self.headerViewController?.removeFromParent()
    self.headerViewController?.didMove(toParent: nil)
    self.headerViewController = headerViewController
    if let headerViewController = headerViewController {
      addChild(headerViewController)
    }
    collectionController.headerView = headerViewController?.view
    headerViewController?.didMove(toParent: self)
  }
}

// MARK: - ActivityListViewInput

extension ActivityListViewController: ActivityListViewInput {
  func updateSections(_ sections: [ActivityListSection]) {
    collectionController.setSections(sections)
  }
  
  func showPagination(_ pagination: ActivityListSection.Pagination) {
    collectionController.showPagination(pagination)
  }
  
  func hidePagination() {
    collectionController.hidePagination()
  }
  
  func hideRefreshControl() {
    if customView.collectionView.refreshControl?.isRefreshing == true {
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        self.customView.collectionView.refreshControl?.endRefreshing()
      }
    }
  }
}

// MARK: - ActivityListCollectionControllerDelegate

extension ActivityListViewController: ActivityListCollectionControllerDelegate {
  func activityListCollectionControllerLoadNextPage(_ collectionController: ActivityListCollectionController) {
    presenter.fetchNext()
  }
  
  func activityListCollectionControllerEventViewModel(for eventId: String) -> ActivityListCompositionTransactionCell.Model? {
    presenter.viewModel(eventId: eventId)
  }
  
  func activityListCollectionControllerDidPullToRefresh(_ collectionController: ActivityListCollectionController) {
    presenter.reload()
    didStartRefresh?()
  }
  
  func activityListCollectionControllerDidSelectAction(_ collectionController: ActivityListCollectionController,
                                                       transactionIndexPath: IndexPath,
                                                       actionIndex: Int) {
    presenter.didSelectTransactionAt(indexPath: transactionIndexPath, actionIndex: actionIndex)
  }
  
  func activityListCollectionControllerDidSelectNFT(_ collectionController: ActivityListCollectionController,
                                                    transactionIndexPath: IndexPath,
                                                    actionIndex: Int) {
    presenter.didSelectNFTAt(indexPath: transactionIndexPath, actionIndex: actionIndex)
  }
}

// MARK: - Private

private extension ActivityListViewController {
  func setup() {
    let refreshControl = UIRefreshControl()
    refreshControl.tintColor = .Icon.primary
    refreshControl.addTarget(self,
                             action: #selector(didPullToRefresh),
                             for: .valueChanged)
    customView.collectionView.refreshControl = refreshControl
  }
  
  @objc
  func didPullToRefresh() {
    guard !customView.collectionView.isDragging else {
      return
    }
    presenter.reload()
  }
}
