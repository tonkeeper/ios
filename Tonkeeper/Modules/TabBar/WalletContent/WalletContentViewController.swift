//
//  WalletContentWalletContentViewController.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 29/05/2023.
//

import UIKit

class WalletContentViewController: GenericViewController<WalletContentView> {
  
  private let pagingContentViewController = PagingContentViewController()

  // MARK: - Module

  private let presenter: WalletContentPresenterInput
  
  var didUpdateHeight: (() -> Void)?
  var didUpdateYContentOffset: ((CGFloat) -> Void)?
  
  private var cachedContentOffsets = [Int: CGFloat]()

  // MARK: - Init

  init(presenter: WalletContentPresenterInput) {
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

// MARK: - WalletContentViewInput

extension WalletContentViewController: WalletContentViewInput {
  func updateContentPages(_ pages: [PagingContent]) {
    pagingContentViewController.contentViewControllers = pages
  }
}

// MARK: - Private

private extension WalletContentViewController {
  func setup() {
    setupPagingContentViewController()
    
    pagingContentViewController.view.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      pagingContentViewController.view.topAnchor.constraint(equalTo: view.topAnchor),
      pagingContentViewController.view.leftAnchor.constraint(equalTo: view.leftAnchor),
      pagingContentViewController.view.rightAnchor.constraint(equalTo: view.rightAnchor),
      pagingContentViewController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
    ])
  }
  
  func setupPagingContentViewController() {
    pagingContentViewController.delegate = self
    
    addChild(pagingContentViewController)
    view.addSubview(pagingContentViewController.view)
    pagingContentViewController.didMove(toParent: self)
  }
}

extension WalletContentViewController: PagingContentViewControllerDelegate {
  func pagingContentViewController(_ pagingContentViewController: PagingContentViewController,
                                   didSelectPageAt index: Int) {
    let contentOffset = cachedContentOffsets[index] ?? 0
    didUpdateYContentOffset?(contentOffset)
    updateYContentOffset(contentOffset)
  }
  
  func pagingContentViewController(_ pagingContentViewController: PagingContentViewController,
                                   didUpdateContentHeightAt index: Int) {
    didUpdateHeight?()
  }
}

extension WalletContentViewController: ScrollContainerBodyContent {
  var height: CGFloat {
    pagingContentViewController.selectedContentViewController.contentHeight
  }

  func resetOffset() {
    cachedContentOffsets = [:]
    pagingContentViewController.scrollableContentViewControllers.forEach {
      $0.scrollView.contentOffset.y = 0
    }
  }
  
  func updateYContentOffset(_ offset: CGFloat) {
    cachedContentOffsets[pagingContentViewController.selectedIndex] = offset
    pagingContentViewController.selectedScrollableContentViewController?.scrollView.contentOffset.y = offset
  }
}
