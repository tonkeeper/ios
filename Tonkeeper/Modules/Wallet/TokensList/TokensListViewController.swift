//
//  TokensListTokensListViewController.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 26/05/2023.
//

import UIKit

class TokensListViewController: GenericViewController<TokensListView>, PagingScrollableContent {
  
  // MARK: - Module

  private let presenter: TokensListPresenterInput
  private let imageLoader: ImageLoader
  
  // MARK: - Collection
  
  private lazy var collectionController = TokensListCollectionController(
    collectionView: customView.collectionView,
    imageLoader: imageLoader
  )
  
  // MARK: - State
  
  private var contentSizeObserveToken: NSKeyValueObservation?
  
  // MARK: - PagingContent
  
  var scrollView: UIScrollView {
    customView.collectionView
  }
  var itemTitle: String? { title }
  var contentHeight: CGFloat {
    let contentHeight = customView.collectionView.contentSize.height
    + customView.collectionView.contentInset.bottom
    let viewHeight = view.bounds.height
    return max(contentHeight, viewHeight)
  }
  
  var didChangeContentHeight: (() -> Void)?

  // MARK: - Init

  init(presenter: TokensListPresenterInput,
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
  
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    didChangeContentHeight?()
  }
}

// MARK: - TokensListViewInput

extension TokensListViewController: TokensListViewInput {
  func presentSections(_ sections: [TokensListSection]) {
    collectionController.sections = sections
  }
}

// MARK: - TokensListCollectionControllerDelegate

extension TokensListViewController: TokensListCollectionControllerDelegate {
  func tokensListCollectionController(_ controller: TokensListCollectionController,
                                      didSelectItemAt indexPath: IndexPath) {
    presenter.didSelectItemAt(indexPath: indexPath)
  }
}

// MARK: - Private

private extension TokensListViewController {
  func setup() {
    contentSizeObserveToken = customView.collectionView
      .observe(\.contentSize, changeHandler: { [weak self] _, _ in
        guard let self else { return }
        self.didChangeContentHeight?()
      })
    
    collectionController.delegate = self
    customView.collectionView.contentInset.bottom = ContentInsets.bottomSpace
  }
}
