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
}

// MARK: - WalletRootViewInput

extension WalletRootViewController: WalletRootViewInput {
  
}

// MARK: - Private

private extension WalletRootViewController {
  func setup() {
    title = "Wallet"
    setupScanQRButton()
    
    addChild(scrollContainerViewController)
    view.addSubview(scrollContainerViewController.view)
    scrollContainerViewController.didMove(toParent: self)

    scrollContainerViewController.view.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      scrollContainerViewController.view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
      scrollContainerViewController.view.leftAnchor.constraint(equalTo: view.leftAnchor),
      scrollContainerViewController.view.rightAnchor.constraint(equalTo: view.rightAnchor),
      scrollContainerViewController.view.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
    ])
  }
  
  func setupScanQRButton() {
    navigationItem.rightBarButtonItem = .init(image: .Icons.Buttons.scanQR,
                                              style: .plain,
                                              target: self,
                                              action: #selector(didTapScanQRButton))
  }
}

// MARK: - Actions

private extension WalletRootViewController {
  @objc
  func didTapScanQRButton() {
    presenter.didTapScanQRButton()
  }
}
