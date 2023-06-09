//
//  ActivityTransactionDetailsActivityTransactionDetailsViewController.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 09/06/2023.
//

import UIKit

class ActivityTransactionDetailsViewController: GenericViewController<ActivityTransactionDetailsView>,
                                                ScrollableModalCardContainerContent {
  
  // MARK: - Module

  private let presenter: ActivityTransactionDetailsPresenterInput
  
  // MARK: - Children
  
  private let modalContentViewController = ModalContentViewController()

  // MARK: - Init

  init(presenter: ActivityTransactionDetailsPresenterInput) {
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
    modalContentViewController.height
  }
  
  var didUpdateHeight: (() -> Void)?
  
  var scrollView: UIScrollView {
    modalContentViewController.scrollView
  }
}

// MARK: - ActivityTransactionDetailsViewInput

extension ActivityTransactionDetailsViewController: ActivityTransactionDetailsViewInput {
  func update(with modalContentConfiguration: ModalContentViewController.Configuration) {
    modalContentViewController.configuration = modalContentConfiguration
  }
}

// MARK: - Private

private extension ActivityTransactionDetailsViewController {
  func setup() {
    setupModalContent()
  }
  
  func setupModalContent() {
    customView.embedContent(modalContentViewController.view)
    modalContentViewController.isRespectSafeArea = false
    modalContentViewController.didUpdateHeight = { [weak self] in
      self?.didUpdateHeight?()
    }
  }
}
