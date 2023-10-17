//
//  FiatMethodPopUpViewController.swift
//  Tonkeeper
//
//  Created by Grigory on 16.10.23..
//

import UIKit

final class FiatMethodPopUpViewController: UIViewController, ScrollableModalCardContainerContent {
  
  // MARK: - Module

  private let presenter: FiatMethodPopUpPresenterInput
  
  // MARK: - ModalContent
  
  private let modalContentViewController = ModalContentViewController()
  
  // MARK: - ScrollableModalCardContainerContent
  
  var scrollView: UIScrollView {
    modalContentViewController.scrollView
  }
  
  var height: CGFloat {
    modalContentViewController.height
  }
  
  var didUpdateHeight: (() -> Void)?
  
  // MARK: - Init

  init(presenter: FiatMethodPopUpPresenterInput) {
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

// MARK: - FiatMethodPopUpViewInput

extension FiatMethodPopUpViewController: FiatMethodPopUpViewInput {
  func updateContent(configuration: ModalContentViewController.Configuration) {
    modalContentViewController.configuration = configuration
  }
}

// MARK: - Private

private extension FiatMethodPopUpViewController {
  func setup() {
    modalContentViewController.isRespectSafeArea = false
    
    view.addSubview(modalContentViewController.view)
    modalContentViewController.view.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      modalContentViewController.view.topAnchor.constraint(equalTo: view.topAnchor),
      modalContentViewController.view.leftAnchor.constraint(equalTo: view.leftAnchor),
      modalContentViewController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      modalContentViewController.view.rightAnchor.constraint(equalTo: view.rightAnchor)
    ])
  }
}
