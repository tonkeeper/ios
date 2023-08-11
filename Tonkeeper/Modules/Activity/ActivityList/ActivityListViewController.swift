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
}

// MARK: - ActivityListViewInput

extension ActivityListViewController: ActivityListViewInput {
  func updateEvents(_ sections: [ActivityListSection]) {
    collectionController.sections = sections
  }
  
  func stopLoading() {
    if customView.collectionView.refreshControl?.isRefreshing == true {
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        self.customView.collectionView.refreshControl?.endRefreshing()
      }
    }
  }
  
  func showShimmer() {
    collectionController.isLoading = true
  }
  
  func hideShimmer() {
    collectionController.isLoading = false
  }
}

// MARK: - ActivityListCollectionControllerDelegate

extension ActivityListViewController: ActivityListCollectionControllerDelegate {
  func activityListCollectionController(_ collectionController: ActivityListCollectionController,
                                        didSelectTransactionAt indexPath: IndexPath) {
    presenter.didSelectTransactionAt(indexPath: indexPath)
  }
  
  func activityListCollectionControllerLoadNextPage(_ collectionController: ActivityListCollectionController) {
    presenter.fetchNext()
  }
  
  func activityListCollectionControllerEventViewModel(for eventId: String) -> ActivityListCompositionTransactionCell.Model? {
    presenter.viewModel(eventId: eventId)
  }
  
  func activityListCollectionControllerDidPullToRefresh(_ collectionController: ActivityListCollectionController) {
    presenter.reload()
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
