//
//  WalletRootViewController.swift
//  Tonkeeper
//
//  Created by Grigory on 23.5.23..
//

import UIKit

final class WalletRootViewController: GenericViewController<WalletRootView>, ScrollViewController {
  
  // MARK: - Module
  
  private let presenter: WalletRootPresenterInput
  
  // MARK: - Children
  
  private let headerViewController: WalletHeaderViewController
  private let contentViewController: WalletContentViewController
  
  // MARK: - ScrollContainer
  
  private let scrollContainerViewController: ScrollContainerViewController
  
  // MARK: - Init
  
  init(presenter: WalletRootPresenterInput,
       headerViewController: WalletHeaderViewController,
       contentViewController: WalletContentViewController) {
    self.presenter = presenter
    self.headerViewController = headerViewController
    self.contentViewController = contentViewController
    self.scrollContainerViewController = .init(
      headerContent: headerViewController,
      bodyContent: contentViewController
    )
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  // MARK: - View Life Cycle
  
  override func viewDidLoad() {
    super.viewDidLoad()
    setup()
    presenter.viewDidLoad()
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    navigationController?.setNavigationBarHidden(true, animated: true)
  }
  
  // MARK: - ScrollViewController
  
  func scrollToTop() {
    if scrollContainerViewController.isScrollOnTop {
      contentViewController.selectFirstTab()
    } else {
      scrollContainerViewController.scrollToTop()
    }
  }
}

// MARK: - WalletRootViewInput

extension WalletRootViewController: WalletRootViewInput {
  func showBanner(bannerModel: WalletHeaderBannerModel) {
    headerViewController.showBanner(bannerModel: bannerModel)
  }
  
  func hideBanner(with identifier: String) {
    headerViewController.hideBanner(with: identifier)
  }
}

// MARK: - Private

private extension WalletRootViewController {
  func setup() {
    addChild(scrollContainerViewController)
    customView.addContent(contentView: scrollContainerViewController.view)
    scrollContainerViewController.didMove(toParent: self)
  }
}
