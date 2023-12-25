//
//  ActivityListActivityListViewController.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 06/06/2023.
//

import UIKit

class ActivityListViewController: GenericViewController<ActivityListView>, ScrollViewController {

  var scrollView: UIScrollView {
    customView.collectionView
  }
  
  private var biggestTopSafeAreaInset: CGFloat = 0
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
  
  override func viewSafeAreaInsetsDidChange() {
    super.viewSafeAreaInsetsDidChange()
    self.biggestTopSafeAreaInset = max(view.safeAreaInsets.top, biggestTopSafeAreaInset)
  }
  
  // MARK: - ScrollViewController

  func scrollToTop() {
    guard !collectionController.isScrollingToTop &&
    scrollView.contentOffset.y > scrollView.adjustedContentInset.top else { return }
    collectionController.isScrollingToTop = true
    scrollView.setContentOffset(
      CGPoint(x: 0,
              y: -scrollView.adjustedContentInset.top),
      animated: true
    )
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
}

// MARK: - ActivityListCollectionControllerDelegate

extension ActivityListViewController: ActivityListCollectionControllerDelegate {
  func activityListCollectionControllerLoadNextPage(_ collectionController: ActivityListCollectionController) {
    presenter.fetchNext()
  }
  
  func activityListCollectionControllerEventViewModel(for eventId: String) -> ActivityListCompositionTransactionCell.Model? {
    presenter.viewModel(eventId: eventId)
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
  func setup() {}
}
