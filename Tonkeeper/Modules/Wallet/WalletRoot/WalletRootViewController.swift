//
//  WalletRootViewController.swift
//  Tonkeeper
//
//  Created by Grigory on 23.5.23..
//

import UIKit

final class WalletRootViewController: GenericViewController<WalletRootView> {
  
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
  }
  
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    
    children.forEach { $0.additionalSafeAreaInsets.top = customView.titleView.frame.height - view.safeAreaInsets.top }
  }
}

// MARK: - WalletRootViewInput

extension WalletRootViewController: WalletRootViewInput {
  
}

// MARK: - Private

private extension WalletRootViewController {
  func setup() {
    title = "Wallet"
    
    addChild(scrollContainerViewController)
    customView.addContent(contentView: scrollContainerViewController.view)
    scrollContainerViewController.didMove(toParent: self)
    
    scrollContainerViewController.didScrollBodyToSafeArea = { [weak self] yOffset in
      self?.updateTitleView(with: yOffset)
    }
    
    customView.titleView.scanQRButton.addTarget(
      self,
      action: #selector(didTapScanQRButton),
      for: .touchUpInside
    )
  }
}

// MARK: - Actions

private extension WalletRootViewController {
  @objc
  func didTapScanQRButton() {
    presenter.didTapScanQRButton()
  }
  
  func updateTitleView(with yOffset: CGFloat) {
    let alpha = yOffset / (customView.titleView.frame.height / 2)
    customView.titleView.alpha = 1 - alpha
    customView.titleView.transform = CGAffineTransform(translationX: 0, y: -yOffset)
  }
}
