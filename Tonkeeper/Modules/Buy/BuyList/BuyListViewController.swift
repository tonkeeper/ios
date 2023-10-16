//
//  BuyListBuyListViewController.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 09/06/2023.
//

import UIKit

class BuyListViewController: GenericViewController<BuyListView>, ScrollableModalCardContainerContent {
  
  // MARK: - Module

  private let presenter: BuyListPresenterInput
  
  // MARK: - Collection
  
  private lazy var collectionController: BuyListCollectionController = {
    let controller = BuyListCollectionController(collectionView: customView.collectionView)
    return controller
  }()
  
  // MARK: - State
  
  private var contentSizeObserveToken: NSKeyValueObservation?
  private var cachedContentHeight: CGFloat = 0

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
  
  // MARK: - ScrollableModalCardContainerContent
  
  var scrollView: UIScrollView {
    customView.collectionView
  }
  
  var height: CGFloat {
    let height = customView.collectionView.contentSize.height
    + customView.collectionView.contentInset.top
    + customView.collectionView.contentInset.bottom
    return height
  }
  
  var didUpdateHeight: (() -> Void)?
}

// MARK: - BuyListViewInput

extension BuyListViewController: BuyListViewInput {
  func updateSections(_ sections: [BuyListSection]) {
    collectionController.sections = sections
  }
  
  func openURL(_ url: URL) {
    let webViewController = WebViewController(url: url)
    let navigationController = UINavigationController(rootViewController: webViewController)
    navigationController.modalPresentationStyle = .fullScreen
    navigationController.configureTransparentAppearance()
    present(navigationController, animated: true)
  }
}

// MARK: - Private

private extension BuyListViewController {
  func setup() {
    title = "Buy or sell"
    
    collectionController.delegate = self
    
    contentSizeObserveToken = customView.collectionView
      .observe(\.contentSize, changeHandler: { [weak self] _, _ in
        guard let self,
              self.customView.collectionView.contentSize.height != self.cachedContentHeight else { return }
        self.cachedContentHeight = self.customView.collectionView.contentSize.height
        self.didUpdateHeight?()
      })
  }
}

// MARK: - BuyListCollectionControllerDelegate

extension BuyListViewController: BuyListCollectionControllerDelegate {
  func buyListCollectionController(_ collectionController: BuyListCollectionController, 
                                   didSelectServiceAt indexPath: IndexPath) {
    presenter.didSelectServiceAt(indexPath: indexPath)
  }
}
