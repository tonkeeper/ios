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
    presenter.viewDidLoad()
  }
}

// MARK: - WalletRootViewInput

extension WalletRootViewController: WalletRootViewInput {
  func update(with model: WalletRootView.Model) {
    customView.configure(model: model)
  }
}

// MARK: - Private

private extension WalletRootViewController {
  func setup() {
    addChild(scrollContainerViewController)
    customView.addContent(contentView: scrollContainerViewController.view)
    scrollContainerViewController.didMove(toParent: self)
    
    customView.setupWalletButton.addTarget(self,
                                           action: #selector(didTapSetupWalletButton),
                                           for: .touchUpInside)
  }
  
  @objc
  func didTapSetupWalletButton() {
    
  }
}
