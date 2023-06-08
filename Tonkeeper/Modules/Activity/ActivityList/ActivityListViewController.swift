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
  func updateSections(_ sections: [ActivityListSection]) {
    collectionController.sections = sections
  }
}

// MARK: - ActivityListCollectionControllerDelegate

extension ActivityListViewController: ActivityListCollectionControllerDelegate {
  func activityListCollectionController(_ collectionController: ActivityListCollectionController,
                                        didSelectTransactionAt indexPath: IndexPath) {
    presenter.didSelectTransactionAt(indexPath: indexPath)
  }
}

// MARK: - Private

private extension ActivityListViewController {
  func setup() {}
}
