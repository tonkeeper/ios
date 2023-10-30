//
//  TonConnectConfirmationViewController.swift
//  Tonkeeper
//
//  Created by Grigory Serebryanyy on 27.10.2023.
//

import UIKit

final class TonConnectConfirmationViewController: UIViewController, ScrollableModalCardContainerContent {
  
  // MARK: - Module
  
  private let presenter: TonConnectConfirmationPresenterInput
  
  // MARK: - Modal Card
  
  private let modalCardViewController = ModalCardViewController()
  
  // MARK: - Init
  
  init(presenter: TonConnectConfirmationPresenterInput) {
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

// MARK: - TonConnectConfirmationViewInput

extension TonConnectConfirmationViewController: TonConnectConfirmationViewInput {
  func update(with configuration: ModalCardViewController.Configuration) {
    modalCardViewController.configuration = configuration
  }
  
  func getHeaderView(appIconURL: URL?) -> UIView {
    let headerView = TonConnectModalHeaderView()
    headerView.imageLoader = NukeImageLoader()
    headerView.configure(
      model: .init(appImage: appIconURL)
    )
    return headerView
  }
}

// MARK: - Private

private extension TonConnectConfirmationViewController {
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

