//
//  TonConnectPopupViewController.swift
//  Tonkeeper
//
//  Created by Grigory Serebryanyy on 25.10.2023.
//

import UIKit

final class TonConnectPopupViewController: UIViewController, ScrollableModalCardContainerContent {
  
  // MARK: - Module
  
  private let presenter: TonConnectPopupPresenterInput
  
  // MARK: - Modal Card
  
  private let modalCardViewController = ModalCardViewController()
  
  // MARK: - Init
  
  init(presenter: TonConnectPopupPresenterInput) {
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
  
  var height: CGFloat {
    modalCardViewController.height
  }
  
  var didUpdateHeight: (() -> Void)?
  
  var scrollView: UIScrollView {
    modalCardViewController.scrollView
  }
}

// MARK: - TonConnectPopupViewInput

extension TonConnectPopupViewController: TonConnectPopupViewInput {
  func update(with configuration: ModalCardViewController.Configuration) {
    modalCardViewController.configuration = configuration
  }
  
  func getHeaderView(walletAddress: String, appIconURL: URL?) -> UIView {
    let headerView = TonConnectModalHeaderView()
    headerView.imageLoader = NukeImageLoader()
    headerView.configure(
      model: .init(walletAddress: walletAddress, appImage: appIconURL)
    )
    return headerView
  }
}

// MARK: - Private

private extension TonConnectPopupViewController {
  func setup() {
    setupModalCard()
  }
  
  func setupModalCard() {
    modalCardViewController.didUpdateHeight = { [weak self] in
      self?.didUpdateHeight?()
    }
    
    addChild(modalCardViewController)
    view.addSubview(modalCardViewController.view)
    modalCardViewController.didMove(toParent: self)
    
    modalCardViewController.view.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      modalCardViewController.view.topAnchor.constraint(equalTo: view.topAnchor),
      modalCardViewController.view.leftAnchor.constraint(equalTo: view.leftAnchor),
      modalCardViewController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      modalCardViewController.view.rightAnchor.constraint(equalTo: view.rightAnchor)
    ])
  }
}
